# Week 10: Kubernetes - the hard way

This project builds a small Kubernetes cluster on three EC2 instances. Terraform creates the AWS infrastructure, and Ansible installs and configures the cluster components.

## Cluster layout

AWS region: `eu-central-1`  
Instance type: `t3.small`  
Operating system: Ubuntu 24.04  
Kubernetes version: `1.36.5`

| Host | Private IP | Role |
|---|---|---|
| controller-0 | 10.20.1.10 | API server, controller manager, scheduler and etcd |
| worker-0 | 10.20.1.20 | Worker node |
| worker-1 | 10.20.1.21 | Worker node |

- Pod network: `10.244.0.0/16`
- Service network: `10.96.0.0/24`
- Cluster DNS: `10.96.0.10`
- Pod networking: Flannel
- DNS: CoreDNS
- Container runtime: containerd

Only the workers appear in `kubectl get nodes`. The controller runs the control plane services without a kubelet.

There is one control plane and one etcd member.

## What Ansible does

The first play in `site.yml` prepares all three hosts: it installs packages, sets hostnames, enables time synchronization, disables swap and configures the kernel networking settings.

The remaining work is split into roles:

| Role | What it configures |
|---|---|
| `generate-certs` | CA, component TLS certificates and ServiceAccount signing keys |
| `generate-configs` | Client kubeconfigs, a persistent 32-byte encryption key and the Secret encryption configuration |
| `bootstrap-etcd` | A TLS-protected etcd member |
| `setup-control-plane` | API server, controller manager, scheduler and kubelet access permissions |
| `setup-worker-nodes` | containerd, CNI plugins, kubelet and kube-proxy |
| `configure-kubectl` | Remote API access check and the local kubectl environment file |
| `setup-networking` | Flannel and CoreDNS |
| `smoke-test` | DNS, exec, logs, cross-node HTTP and Secret encryption checks |

## Before running it

The local machine needs:

- AWS CLI with the `aws-learning` profile configured
- Terraform
- Ansible with the `community.crypto` collection
- `cryptography` installed in the Python environment used by Ansible
- kubectl and OpenSSL

Check AWS access:

```bash
aws sts get-caller-identity \
  --profile aws-learning \
  --region eu-central-1
```

For a fresh checkout, create the SSH key used by Terraform and Ansible:

```bash
mkdir -p .secrets
chmod 700 .secrets

ssh-keygen -t ed25519 \
  -f .secrets/k8s-lab \
  -N '' \
  -C week10-k8s

ansible-galaxy collection install community.crypto
```

The `.secrets` directory holds private keys, generated certificates, kubeconfigs and the encryption configuration. It is excluded from Git.

## Create the cluster

Run these commands from the project root:

```bash
terraform -chdir=terraform init
./update-access.sh
```

Terraform creates the VPC, public subnet, Internet Gateway, routing, Security Group, SSH key pair and three EC2 instances.

`update-access.sh` detects the current public IP of the local machine, updates `admin_cidr`, runs Terraform and writes the EC2 addresses into the Ansible inventory. Terraform asks for confirmation before applying changes.

Then install Kubernetes:

```bash
cd ansible

ansible k8s -b -m ping
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml
```

Load the generated admin kubeconfig:

```bash
source ../.secrets/kubectl-env.sh

kubectl get nodes -o wide
kubectl get pods -A
```

In a new terminal, source the environment file again before using kubectl.

## Check the cluster

From the `ansible` directory:

```bash
ansible-playbook site.yml --tags smoke-test
```

The role creates its resources in the `smoke-test` namespace. The client runs on `worker-0`, and the HTTP server runs on `worker-1`, so the HTTP request through the Service crosses the node boundary.

The tests also execute commands inside a Pod, read container logs and resolve the Kubernetes Service through cluster DNS.

For encryption, the role writes a test Secret, reads its value through the API and checks the raw etcd record for this prefix:

```text
k8s:enc:secretbox:v1:key1:
```

The final test rerun completed with `changed=0`, `unreachable=0` and `failed=0`.

Useful commands for checking the current state:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get --raw='/readyz?verbose'
kubectl -n smoke-test get pods -o wide
```

Both workers should be `Ready`. Flannel, CoreDNS and the automated test Pods should be running.

## Open the test application

The test application uses an internal ClusterIP Service. To access it from the local browser:

```bash
kubectl -n smoke-test port-forward service/smoke-server 8080:80
```

Keep that command running and open:

```text
http://localhost:8080
```

The response should be `smoke-ok`. Press `Ctrl+C` to close the tunnel.

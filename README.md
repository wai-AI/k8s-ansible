# Kubernetes на AWS через Terraform та Ansible

Навчальний Kubernetes-кластер, встановлений вручну без kubeadm.

## Архітектура

Регіон AWS: eu-central-1. ОС: Ubuntu 24.04.
Kubernetes: v1.36.5.

| Вузол | Приватна IP | Призначення |
|---|---|---|
| controller-0 | 10.20.1.10 | Control plane та etcd |
| worker-0 | 10.20.1.20 | Worker |
| worker-1 | 10.20.1.21 | Worker |

Pod CIDR: 10.244.0.0/16.
Service CIDR: 10.96.0.0/24.
DNS: 10.96.0.10.

Це навчальна конфігурація з одним control plane та одним
членом etcd, без високої доступності.

## Етапи встановлення

1. Terraform створює VPC, підмережу, Internet Gateway,
   маршрути, Security Group, SSH key pair і три EC2.
2. Перший play у site.yml налаштовує hostname, пакети,
   синхронізацію часу, swap, модулі ядра та sysctl.
3. generate-certs створює CA, TLS-сертифікати та ключі
   підпису ServiceAccount.
4. generate-configs створює kubeconfig-файли та конфігурацію
   шифрування Secrets: secretbox із 32-байтовим ключем.
5. bootstrap-etcd запускає etcd із TLS.
6. setup-control-plane запускає API server, controller manager
   і scheduler як systemd-сервіси.
7. setup-worker-nodes встановлює containerd, CNI-плагіни,
   kubelet і kube-proxy.
8. configure-kubectl налаштовує віддалений доступ адміністратора.
9. setup-networking розгортає Flannel і CoreDNS.
10. smoke-test автоматично перевіряє працездатність кластера.

## Відтворення

Потрібні AWS CLI з профілем aws-learning, Terraform, Ansible,
kubectl, OpenSSL, колекція community.crypto та Python
із cryptography для локальних криптографічних задач.

Для нового клону спочатку створити SSH-ключ:
```bash
mkdir -p .secrets
chmod 700 .secrets
ssh-keygen -t ed25519 -f .secrets/k8s-lab -N '' -C week10-k8s
```

Із кореня проєкту:
```bash
terraform -chdir=terraform init
./update-access.sh

cd ansible
ansible k8s -b -m ping
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml

source ../.secrets/kubectl-env.sh
kubectl get nodes -o wide
kubectl get pods -A
```

update-access.sh оновлює дозволену зовнішню IP адміністратора,
застосовує Terraform і генерує актуальний Ansible inventory.

## Перевірки

```bash
ansible-playbook site.yml --tags smoke-test
kubectl -n smoke-test get pods -o wide
```

Підтверджено:
- обидва worker-вузли мають статус Ready;
- DNS повертає адресу Kubernetes Service;
- працюють kubectl exec та отримання логів;
- HTTP-запит через Service проходить між різними worker-вузлами;
- Secret читається через API;
- запис Secret у etcd має префікс k8s:enc:secretbox:v1:key1:;
- повторний запуск smoke-test: changed=0, failed=0.

## Проблеми та рішення

| Проблема | Рішення |
|---|---|
| Зміна IP адміністратора спричинила SSH timeout | Автоматичне оновлення admin_cidr через update-access.sh |
| Після повторного створення EC2 inventory містив старі IP | Генерація inventory з Terraform outputs |
| Worker-вузли були NotReady до встановлення мережі | Встановлення Flannel |
| kubectl run не встиг підключитися до короткого DNS-тесту | Перевірка exec через довготривалий Pod |
| Повторне створення Service повертало AlreadyExists | Використання kubectl apply в автоматизації |

## Видалення

Із кореня проєкту:
```bash
terraform -chdir=terraform destroy
terraform -chdir=terraform state list
```

Приватні ключі, kubeconfig-файли та конфігурація шифрування
зберігаються в .secrets і виключені з Git.
# k8s-ansible

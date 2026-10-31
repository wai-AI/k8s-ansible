output "account_id" {
  description = "AWS account used by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "nodes" {
  description = "Cluster nodes and their IP addresses"

  value = {
    for name, node in aws_instance.nodes : name => {
      public_ip  = node.public_ip
      private_ip = node.private_ip
    }
  }
}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ansible_inventory" {
  value = <<-INI
[control_plane]
controller-0 ansible_host=${aws_instance.nodes["controller-0"].public_ip} private_ip=${aws_instance.nodes["controller-0"].private_ip}

[workers]
worker-0 ansible_host=${aws_instance.nodes["worker-0"].public_ip} private_ip=${aws_instance.nodes["worker-0"].private_ip}
worker-1 ansible_host=${aws_instance.nodes["worker-1"].public_ip} private_ip=${aws_instance.nodes["worker-1"].private_ip}

[etcd:children]
control_plane

[k8s:children]
control_plane
workers
INI
}

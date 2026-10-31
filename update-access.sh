#!/bin/sh
set -eu

cd "$(dirname "$0")"

operator_ip=$(curl -4 -fsS https://checkip.amazonaws.com)

printf 'admin_cidr = "%s/32"\n' "$operator_ip" \
  > terraform/access.auto.tfvars

terraform -chdir=terraform apply

terraform -chdir=terraform output -raw ansible_inventory \
  > ansible/inventory.ini

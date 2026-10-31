terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}

resource "aws_key_pair" "k8s" {
  key_name   = "week10-k8s"
  public_key = file("${path.module}/../.secrets/k8s-lab.pub")
}

resource "aws_vpc" "k8s" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "week10-k8s"
  }
}

resource "aws_subnet" "k8s" {
  vpc_id                  = aws_vpc.k8s.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "week10-k8s-subnet"
  }
}

resource "aws_internet_gateway" "k8s" {
  vpc_id = aws_vpc.k8s.id

  tags = {
    Name = "week10-k8s"
  }
}

resource "aws_route_table" "k8s" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s.id
  }

  tags = {
    Name = "week10-k8s"
  }
}

resource "aws_route_table_association" "k8s" {
  subnet_id      = aws_subnet.k8s.id
  route_table_id = aws_route_table.k8s.id
}

resource "aws_security_group" "k8s" {
  name        = "week10-k8s"
  description = "Access to the Kubernetes lab"
  vpc_id      = aws_vpc.k8s.id

  ingress {
    description = "SSH from my computer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Kubernetes API from my computer"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Internal cluster communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "week10-k8s"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

locals {
  nodes = {
    "controller-0" = "10.20.1.10"
    "worker-0"     = "10.20.1.20"
    "worker-1"     = "10.20.1.21"
  }
}

resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.k8s.id
  private_ip             = each.value
  key_name               = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s.id]

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "week10-k8s-${each.key}"
  }

  depends_on = [aws_route_table_association.k8s]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  # Credentials come from ~/.aws/credentials (configured via `aws configure`)
  # Never hardcode Access Key / Secret Key here
}

# ─────────────────────────────────────────────
# SSH KEY PAIR — for EC2 access
# ─────────────────────────────────────────────
# Generates a local key pair and uploads the PUBLIC key to AWS.
# PRIVATE key is saved locally to ~/terraform-key.pem on the Jenkins VM.

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.k8s_key.public_key_openssh

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = pathexpand("~/${var.key_pair_name}.pem")
  file_permission = "0400"  # owner read only — required for SSH
}

# ─────────────────────────────────────────────
# EC2 — K8s MASTER NODE
# ─────────────────────────────────────────────
resource "aws_instance" "k8s_master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k8s_master_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20   # GB — enough for K8s + Docker images
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-k8s-master"
    Role    = "master"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────────
# EC2 — K8s WORKER NODE
# ─────────────────────────────────────────────
resource "aws_instance" "k8s_worker" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k8s_worker_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-k8s-worker"
    Role    = "worker"
    Project = var.project_name
  }
}

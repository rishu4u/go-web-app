variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "go-web-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type (t3.medium = 2 vCPU, 4GB — minimum for K8s)"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS us-east-1 (2024)
}

variable "key_pair_name" {
  description = "Name for the EC2 SSH key pair"
  type        = string
  default     = "terraform-key"
}

variable "my_ip" {
  description = "Your public IP for SSH access (format: x.x.x.x/32)"
  type        = string
  # Set in terraform.tfvars — get yours with: curl ifconfig.me
}

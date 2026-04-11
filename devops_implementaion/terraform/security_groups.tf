# ─────────────────────────────────────────────
# SECURITY GROUP — K8s MASTER NODE
# ─────────────────────────────────────────────
resource "aws_security_group" "k8s_master_sg" {
  name        = "${var.project_name}-master-sg"
  description = "Security group for K8s master node"
  vpc_id      = aws_vpc.main.id

  # SSH — only from your IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Kubernetes API — kubectl uses this port
  ingress {
    description = "K8s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # etcd — inter-node communication
  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # only within VPC
  }

  # Kubelet API + scheduler + controller manager
  ingress {
    description = "K8s control plane"
    from_port   = 10250
    to_port     = 10260
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all traffic from within VPC (master ↔ worker communication)
  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-master-sg"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────────
# SECURITY GROUP — K8s WORKER NODE
# ─────────────────────────────────────────────
resource "aws_security_group" "k8s_worker_sg" {
  name        = "${var.project_name}-worker-sg"
  description = "Security group for K8s worker nodes"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # App traffic — HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App traffic — HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Go app port (NodePort range for K8s services)
  ingress {
    description = "App NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet + Flannel/Calico CNI
  ingress {
    description = "K8s worker ports"
    from_port   = 10250
    to_port     = 10260
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all traffic within VPC (worker ↔ master communication)
  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-worker-sg"
    Project = var.project_name
  }
}

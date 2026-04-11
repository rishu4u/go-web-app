output "k8s_master_public_ip" {
  description = "Public IP of the K8s master node — use this to SSH in"
  value       = aws_instance.k8s_master.public_ip
}

output "k8s_worker_public_ip" {
  description = "Public IP of the K8s worker node"
  value       = aws_instance.k8s_worker.public_ip
}

output "k8s_master_private_ip" {
  description = "Private IP of master (used for kubeadm join command)"
  value       = aws_instance.k8s_master.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ssh_command_master" {
  description = "SSH command to connect to master node"
  value       = "ssh -i ~/${var.key_pair_name}.pem ubuntu@${aws_instance.k8s_master.public_ip}"
}

output "ssh_command_worker" {
  description = "SSH command to connect to worker node"
  value       = "ssh -i ~/${var.key_pair_name}.pem ubuntu@${aws_instance.k8s_worker.public_ip}"
}

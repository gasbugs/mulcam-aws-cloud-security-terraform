output "client_vpn_client_cidr_block" {
  description = "Client CIDR block to use when manually creating an AWS Client VPN endpoint."
  value       = var.client_vpn_client_cidr_block
}

output "private_instance_id" {
  description = "ID of the private EC2 instance."
  value       = aws_instance.private.id
}

output "private_instance_private_ip" {
  description = "Private IP address of the private EC2 instance."
  value       = aws_instance.private.private_ip
}

output "private_instance_security_group_id" {
  description = "Security group ID attached to the private EC2 instance."
  value       = aws_security_group.private_instance.id
}

output "private_route_table_ids" {
  description = "Private route table IDs keyed by availability zone."
  value = {
    for availability_zone, route_table in aws_route_table.private : availability_zone => route_table.id
  }
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.private : availability_zone => subnet.id
  }
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  value = {
    for availability_zone, subnet in aws_subnet.public : availability_zone => subnet.id
  }
}

output "ssh_key_pair_name" {
  description = "Name of the EC2 key pair attached to the private instance for SSH tests."
  value       = aws_key_pair.ssh.key_name
}

output "ssh_private_key_file" {
  description = "Local path where Terraform writes the generated SSH private key PEM file."
  value       = local_sensitive_file.ssh_private_key.filename
}

output "ssh_via_client_vpn_command" {
  description = "Example SSH command after connecting through Client VPN."
  value       = "ssh -i ${local_sensitive_file.ssh_private_key.filename} ec2-user@${aws_instance.private.private_ip}"
}

output "vpc_cidr_block" {
  description = "CIDR block of the lab VPC."
  value       = aws_vpc.main.cidr_block
}

output "vpc_id" {
  description = "ID of the lab VPC."
  value       = aws_vpc.main.id
}

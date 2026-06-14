output "client_vpn_endpoint_dns_name" {
  description = "DNS name of the Client VPN endpoint when enabled."
  value       = try(aws_ec2_client_vpn_endpoint.main[0].dns_name, null)
}

output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint when enabled."
  value       = try(aws_ec2_client_vpn_endpoint.main[0].id, null)
}

output "client_vpn_security_group_id" {
  description = "Security group ID attached to the Client VPN endpoint when enabled."
  value       = try(aws_security_group.client_vpn[0].id, null)
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway when enabled."
  value       = try(aws_nat_gateway.main[0].id, null)
}

output "private_instance_id" {
  description = "ID of the private EC2 instance used for Session Manager tests."
  value       = try(aws_instance.private[0].id, null)
}

output "private_instance_private_ip" {
  description = "Private IP address of the Session Manager test instance."
  value       = try(aws_instance.private[0].private_ip, null)
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

output "session_manager_start_command" {
  description = "AWS CLI command for starting a Session Manager shell to the private instance."
  value       = try("aws ssm start-session --target ${aws_instance.private[0].id} --region ${var.aws_region}", null)
}

output "ssh_key_pair_name" {
  description = "Name of the EC2 key pair attached to the private instance for SSH tests."
  value       = try(aws_key_pair.ssh[0].key_name, null)
}

output "ssh_private_key_file" {
  description = "Local path where Terraform writes the generated SSH private key PEM file."
  value       = try(local_sensitive_file.ssh_private_key[0].filename, null)
}

output "ssh_via_client_vpn_command" {
  description = "Example SSH command after connecting through Client VPN."
  value       = try("ssh -i ${local_sensitive_file.ssh_private_key[0].filename} ec2-user@${aws_instance.private[0].private_ip}", null)
}

output "ssm_endpoint_ids" {
  description = "SSM interface endpoint IDs keyed by service name when enabled."
  value = {
    for service, endpoint in aws_vpc_endpoint.ssm : service => endpoint.id
  }
}

output "vpc_cidr_block" {
  description = "CIDR block of the lab VPC."
  value       = aws_vpc.main.cidr_block
}

output "vpc_id" {
  description = "ID of the lab VPC."
  value       = aws_vpc.main.id
}

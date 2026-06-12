output "account_id" {
  description = "AWS account ID where the workshop resources are deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "cidr_blocks" {
  description = "CIDR blocks for the two VPCs used in the console peering workshop."
  value = {
    for name, config in local.vpcs : name => config.cidr_block
  }
}

output "connectivity_expectations" {
  description = "Expected connectivity before and after students complete the console work."
  value       = local.connectivity_expectations
}

output "instance_ids" {
  description = "EC2 instance IDs used for SSM Session Manager and ping tests."
  value = {
    for name, instance in aws_instance.this : name => instance.id
  }
}

output "private_ips" {
  description = "Private IP addresses used for ICMP connectivity tests."
  value = {
    for name, instance in aws_instance.this : name => instance.private_ip
  }
}

output "route_table_ids" {
  description = "Route table IDs where students add VPC peering routes in the console."
  value = {
    for name, route_table in aws_route_table.private : name => route_table.id
  }
}

output "security_group_ids" {
  description = "Security group IDs where students add ICMP inbound firewall rules in the console."
  value = {
    for name, security_group in aws_security_group.instance : name => security_group.id
  }
}

output "student_console_checklist" {
  description = "Manual console tasks students should complete after Terraform preparation."
  value = [
    "Create a VPC peering connection between app and shared VPCs.",
    "Accept the VPC peering connection.",
    "Add an app route table route to the shared CIDR through the peering connection.",
    "Add a shared route table route to the app CIDR through the peering connection.",
    "Add ICMP inbound rules on both instance security groups using the opposite VPC CIDR.",
    "Use SSM Session Manager to ping between the private instance IPs.",
  ]
}

output "vpc_ids" {
  description = "VPC IDs for the console peering workshop."
  value = {
    for name, vpc in aws_vpc.this : name => vpc.id
  }
}

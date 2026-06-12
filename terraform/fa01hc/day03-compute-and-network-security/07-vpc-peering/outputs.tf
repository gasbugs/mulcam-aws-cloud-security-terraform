output "connectivity_expectations" {
  description = "Expected connectivity matrix for hub and spoke traffic."
  value       = local.connectivity_expectations
}

output "instance_ids" {
  description = "EC2 instance IDs used for SSM connectivity tests."
  value = {
    for name, instance in aws_instance.this : name => instance.id
  }
}

output "private_ips" {
  description = "Private IP addresses used in ICMP connectivity tests."
  value = {
    for name, instance in aws_instance.this : name => instance.private_ip
  }
}

output "tgw_id" {
  description = "ID of the Transit Gateway hub."
  value       = aws_ec2_transit_gateway.main.id
}

output "tgw_route_table_ids" {
  description = "Transit Gateway route table IDs for hub-originated and spoke-originated traffic."
  value = {
    from_hub    = aws_ec2_transit_gateway_route_table.from_hub.id
    from_spokes = aws_ec2_transit_gateway_route_table.from_spokes.id
  }
}

output "vpc_ids" {
  description = "VPC IDs for the hub and spoke networks."
  value = {
    for name, vpc in aws_vpc.this : name => vpc.id
  }
}

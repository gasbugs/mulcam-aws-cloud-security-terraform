output "account_id" {
  description = "AWS account ID where the workshop resources are deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "cidr_blocks" {
  description = "CIDR blocks for workload and inspection VPCs."
  value = {
    for name, config in local.vpcs : name => config.cidr_block
  }
}

output "connectivity_expectations" {
  description = "Expected connectivity before and after students complete firewall insertion and routing."
  value       = local.connectivity_expectations
}

output "inspection_subnet_ids" {
  description = "Inspection VPC subnet IDs used for Network Firewall and Transit Gateway attachment."
  value = {
    firewall = aws_subnet.inspection_firewall.id
    tgw      = aws_subnet.inspection_tgw.id
  }
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
  description = "Route table IDs where students add workload, inspection, and firewall routes in the console."
  value = {
    app_private         = aws_route_table.private["app"].id
    app_tgw             = aws_route_table.workload_tgw["app"].id
    inspection_firewall = aws_route_table.inspection_firewall.id
    inspection_tgw      = aws_route_table.inspection_tgw.id
    shared_private      = aws_route_table.private["shared"].id
    shared_tgw          = aws_route_table.workload_tgw["shared"].id
  }
}

output "security_group_ids" {
  description = "Security group IDs for workload instances and SSM interface endpoints."
  value = {
    app_instance        = aws_security_group.instance["app"].id
    app_ssm_endpoint    = aws_security_group.endpoint["app"].id
    shared_instance     = aws_security_group.instance["shared"].id
    shared_ssm_endpoint = aws_security_group.endpoint["shared"].id
  }
}

output "student_console_checklist" {
  description = "Manual console tasks students should complete after Terraform preparation."
  value = [
    "Create a Transit Gateway with default route table association and propagation disabled.",
    "Create app, shared, and inspection VPC attachments. Enable appliance mode on the inspection attachment.",
    "Create Transit Gateway route tables for workload-originated and inspection-originated traffic.",
    "Associate app/shared attachments with the workload TGW route table and the inspection attachment with the inspection TGW route table.",
    "Create a stateless Network Firewall rule group that passes ICMP between app and shared CIDRs.",
    "Create a firewall policy that uses the stateless ICMP rule group and drops unmatched traffic.",
    "Create AWS Network Firewall in the inspection VPC firewall subnet and copy its endpoint ID.",
    "Add app/shared private subnet routes to the student-created Transit Gateway.",
    "Add workload TGW route table routes to the inspection attachment.",
    "Add inspection TGW subnet routes to the Network Firewall endpoint.",
    "Add inspection firewall subnet routes back to the student-created Transit Gateway.",
    "Add inspection TGW route table routes back to app and shared attachments.",
    "Use SSM Session Manager to ping between the private instance IPs.",
  ]
}

output "suggested_console_names" {
  description = "Suggested names for Transit Gateway and Network Firewall resources students create in the console."
  value       = local.suggested_console_names
}

output "vpc_ids" {
  description = "VPC IDs for the centralized inspection workshop."
  value = {
    for name, vpc in aws_vpc.this : name => vpc.id
  }
}

output "workload_subnet_ids" {
  description = "Private subnet IDs where workload EC2 instances run."
  value = {
    for name, subnet in aws_subnet.private : name => subnet.id
  }
}

output "workload_tgw_subnet_ids" {
  description = "Dedicated subnet IDs used for workload Transit Gateway attachments."
  value = {
    for name, subnet in aws_subnet.workload_tgw : name => subnet.id
  }
}

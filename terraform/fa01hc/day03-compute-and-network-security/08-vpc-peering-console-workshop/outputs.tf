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

output "cli_export_commands" {
  description = "Shell export commands for the AWS CLI-based Network Firewall lab."
  value       = <<-EOT
    export AWS_REGION=${var.aws_region}
    export PROJECT_NAME=${var.project_name}
    export APP_VPC_ID=${aws_vpc.this["app"].id}
    export SHARED_VPC_ID=${aws_vpc.this["shared"].id}
    export INSPECTION_VPC_ID=${aws_vpc.this["inspection"].id}
    export APP_CIDR=${local.vpcs["app"].cidr_block}
    export SHARED_CIDR=${local.vpcs["shared"].cidr_block}
    export INSPECTION_CIDR=${local.vpcs["inspection"].cidr_block}
    export APP_TGW_SUBNET_ID=${aws_subnet.workload_tgw["app"].id}
    export SHARED_TGW_SUBNET_ID=${aws_subnet.workload_tgw["shared"].id}
    export INSPECTION_TGW_SUBNET_ID=${aws_subnet.inspection_tgw.id}
    export INSPECTION_FIREWALL_SUBNET_ID=${aws_subnet.inspection_firewall.id}
    export INSPECTION_FIREWALL_AZ=${aws_subnet.inspection_firewall.availability_zone}
    export APP_PRIVATE_RT_ID=${aws_route_table.private["app"].id}
    export SHARED_PRIVATE_RT_ID=${aws_route_table.private["shared"].id}
    export INSPECTION_TGW_RT_ID=${aws_route_table.inspection_tgw.id}
    export INSPECTION_FIREWALL_RT_ID=${aws_route_table.inspection_firewall.id}
    export APP_INSTANCE_ID=${aws_instance.this["app"].id}
    export SHARED_INSTANCE_ID=${aws_instance.this["shared"].id}
    export APP_PRIVATE_IP=${aws_instance.this["app"].private_ip}
    export SHARED_PRIVATE_IP=${aws_instance.this["shared"].private_ip}
    export TGW_NAME=${local.suggested_resource_names.tgw}
    export TGW_APP_ATTACHMENT_NAME=${local.suggested_resource_names.tgw_app_attachment}
    export TGW_SHARED_ATTACHMENT_NAME=${local.suggested_resource_names.tgw_shared_attachment}
    export TGW_INSPECTION_ATTACHMENT_NAME=${local.suggested_resource_names.tgw_inspection_attachment}
    export TGW_FROM_WORKLOADS_RT_NAME=${local.suggested_resource_names.tgw_from_workloads_rt}
    export TGW_FROM_INSPECTION_RT_NAME=${local.suggested_resource_names.tgw_from_inspection_rt}
    export FIREWALL_RULE_GROUP_NAME=${local.suggested_resource_names.firewall_rule_group}
    export FIREWALL_POLICY_NAME=${local.suggested_resource_names.firewall_policy}
    export NETWORK_FIREWALL_NAME=${local.suggested_resource_names.network_firewall}
  EOT
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
  description = "Route table IDs where students add workload, inspection, and firewall routes."
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

output "student_cli_checklist" {
  description = "AWS CLI tasks students should complete after Terraform preparation."
  value       = local.student_cli_checklist
}

output "student_console_checklist" {
  description = "Deprecated compatibility output. Use student_cli_checklist for the AWS CLI-based lab."
  value       = local.student_cli_checklist
}

output "suggested_console_names" {
  description = "Deprecated compatibility output. Use suggested_resource_names for the AWS CLI-based lab."
  value       = local.suggested_resource_names
}

output "suggested_resource_names" {
  description = "Suggested names for Transit Gateway and Network Firewall resources students create with AWS CLI."
  value       = local.suggested_resource_names
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

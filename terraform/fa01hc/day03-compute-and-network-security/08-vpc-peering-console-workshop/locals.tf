locals {
  availability_zone = data.aws_availability_zones.available.names[0]

  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "inspection-firewall-cli"
  }

  connectivity_expectations = {
    "app-to-shared-before-firewall-routing" = "blocked"
    "app-to-shared-after-firewall-routing"  = "allowed-through-network-firewall"
    "shared-to-app-after-firewall-routing"  = "allowed-through-network-firewall"
  }

  inspection_vpc_key = "inspection"

  suggested_resource_names = {
    firewall_policy           = "${var.project_name}-policy"
    firewall_rule_group       = "${var.project_name}-allow-icmp-rule-group"
    network_firewall          = "${var.project_name}-firewall"
    tgw                       = "${var.project_name}-tgw"
    tgw_app_attachment        = "${var.project_name}-app-tgw-attachment"
    tgw_from_inspection_rt    = "${var.project_name}-tgw-rt-from-inspection"
    tgw_from_workloads_rt     = "${var.project_name}-tgw-rt-from-workloads"
    tgw_inspection_attachment = "${var.project_name}-inspection-tgw-attachment"
    tgw_shared_attachment     = "${var.project_name}-shared-tgw-attachment"
  }

  student_cli_checklist = [
    "Create a Transit Gateway with default route table association and propagation disabled.",
    "Create app, shared, and inspection VPC attachments. Enable appliance mode on the inspection attachment.",
    "Create Transit Gateway route tables for workload-originated and inspection-originated traffic.",
    "Associate app/shared attachments with the workload TGW route table and the inspection attachment with the inspection TGW route table.",
    "Create a stateful Network Firewall rule group that passes ICMP between app and shared CIDRs.",
    "Create a strict-order firewall policy that forwards traffic to the stateful engine and drops unmatched traffic.",
    "Create AWS Network Firewall in the inspection VPC firewall subnet and read its endpoint ID from describe-firewall.",
    "Add app/shared private subnet routes to the student-created Transit Gateway.",
    "Add the workload TGW route table default route to the inspection attachment.",
    "Add the inspection TGW subnet default route to the Network Firewall endpoint.",
    "Add the inspection firewall subnet default route back to the student-created Transit Gateway.",
    "Add inspection TGW route table routes back to app and shared attachments.",
    "Use SSM Run Command or Session Manager to ping between the private instance IPs.",
  ]

  ssm_services = toset([
    "ec2messages",
    "ssm",
    "ssmmessages",
  ])

  vpcs = {
    app = {
      cidr_block          = "10.30.0.0/16"
      private_subnet_cidr = "10.30.1.0/24"
      role                = "workload"
      tgw_subnet_cidr     = "10.30.2.0/24"
    }
    inspection = {
      cidr_block           = "10.50.0.0/16"
      firewall_subnet_cidr = "10.50.1.0/24"
      role                 = "inspection"
      tgw_subnet_cidr      = "10.50.2.0/24"
    }
    shared = {
      cidr_block          = "10.40.0.0/16"
      private_subnet_cidr = "10.40.1.0/24"
      role                = "workload"
      tgw_subnet_cidr     = "10.40.2.0/24"
    }
  }

  workload_vpcs = {
    for name, config in local.vpcs : name => config
    if config.role == "workload"
  }

  ssm_endpoint_matrix = {
    for pair in setproduct(keys(local.workload_vpcs), local.ssm_services) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[1]
      vpc_key = pair[0]
    }
  }
}

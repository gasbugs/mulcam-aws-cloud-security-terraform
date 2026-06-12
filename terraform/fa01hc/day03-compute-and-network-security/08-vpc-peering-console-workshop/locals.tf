locals {
  availability_zone = data.aws_availability_zones.available.names[0]

  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "inspection-firewall-console"
  }

  connectivity_expectations = {
    "app-to-shared-before-firewall-routing" = "blocked"
    "app-to-shared-after-firewall-routing"  = "allowed-through-network-firewall"
    "shared-to-app-after-firewall-routing"  = "allowed-through-network-firewall"
  }

  inspection_vpc_key = "inspection"

  suggested_console_names = {
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

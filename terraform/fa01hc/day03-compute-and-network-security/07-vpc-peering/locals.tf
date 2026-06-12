locals {
  availability_zone = data.aws_availability_zones.available.names[0]

  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "hub-spoke-tgw"
  }

  connectivity_expectations = {
    "hub-to-spoke-a"     = "allowed"
    "hub-to-spoke-b"     = "allowed"
    "spoke-a-to-hub"     = "allowed"
    "spoke-b-to-hub"     = "allowed"
    "spoke-a-to-spoke-b" = "blocked"
    "spoke-b-to-spoke-a" = "blocked"
  }

  ssm_services = toset([
    "ec2messages",
    "ssm",
    "ssmmessages",
  ])

  vpcs = {
    hub = {
      cidr_block          = "10.0.0.0/16"
      private_subnet_cidr = "10.0.1.0/24"
      role                = "hub"
    }
    spoke-a = {
      cidr_block          = "10.10.0.0/16"
      private_subnet_cidr = "10.10.1.0/24"
      role                = "spoke"
    }
    spoke-b = {
      cidr_block          = "10.20.0.0/16"
      private_subnet_cidr = "10.20.1.0/24"
      role                = "spoke"
    }
  }

  spoke_vpcs = {
    for name, config in local.vpcs : name => config
    if config.role == "spoke"
  }

  ssm_endpoint_matrix = {
    for pair in setproduct(keys(local.vpcs), local.ssm_services) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[1]
      vpc_key = pair[0]
    }
  }

  vpc_routes_to_tgw = merge(
    {
      for name, config in local.spoke_vpcs :
      "${name}-to-hub" => {
        destination_cidr_block = local.vpcs.hub.cidr_block
        route_table_key        = name
      }
    },
    {
      for name, config in local.spoke_vpcs :
      "hub-to-${name}" => {
        destination_cidr_block = config.cidr_block
        route_table_key        = "hub"
      }
    }
  )
}

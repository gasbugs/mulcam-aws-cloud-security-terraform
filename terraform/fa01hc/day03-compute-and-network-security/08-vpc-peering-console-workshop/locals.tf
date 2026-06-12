locals {
  availability_zone = data.aws_availability_zones.available.names[0]

  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "vpc-peering-console"
  }

  connectivity_expectations = {
    "app-to-shared-before-console-work" = "blocked"
    "app-to-shared-after-console-work"  = "allowed"
    "shared-to-app-after-console-work"  = "allowed"
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
      role                = "requester"
    }
    shared = {
      cidr_block          = "10.40.0.0/16"
      private_subnet_cidr = "10.40.1.0/24"
      role                = "accepter"
    }
  }

  ssm_endpoint_matrix = {
    for pair in setproduct(keys(local.vpcs), local.ssm_services) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[1]
      vpc_key = pair[0]
    }
  }
}

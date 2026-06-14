locals {
  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "vpc-network-foundation"
  }

  selected_availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  subnet_map = {
    for index, availability_zone in local.selected_availability_zones : availability_zone => {
      private_cidr = cidrsubnet(var.vpc_cidr, 8, index + 10)
      public_cidr  = cidrsubnet(var.vpc_cidr, 8, index)
    }
  }

  first_availability_zone = local.selected_availability_zones[0]
}

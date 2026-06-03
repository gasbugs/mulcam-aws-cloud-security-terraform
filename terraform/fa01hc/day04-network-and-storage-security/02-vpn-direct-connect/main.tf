locals {
  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "vpn-direct-connect"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.44.0.0/16"
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vgw"
  })
}

resource "aws_customer_gateway" "main" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cgw"
  })
}

resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.main.id
  static_routes_only  = true
  type                = "ipsec.1"
  vpn_gateway_id      = aws_vpn_gateway.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-site-to-site"
  })
}

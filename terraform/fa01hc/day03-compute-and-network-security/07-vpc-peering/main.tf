locals {
  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "vpc-peering"
  }
}

resource "aws_vpc" "app" {
  cidr_block           = "10.41.0.0/16"
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app"
  })
}

resource "aws_vpc" "shared" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-shared"
  })
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block                = aws_vpc.shared.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app-rt"
  })
}

resource "aws_route_table" "shared" {
  vpc_id = aws_vpc.shared.id

  route {
    cidr_block                = aws_vpc.app.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-shared-rt"
  })
}

resource "aws_vpc_peering_connection" "main" {
  auto_accept = true
  peer_vpc_id = aws_vpc.shared.id
  vpc_id      = aws_vpc.app.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-peer"
  })
}

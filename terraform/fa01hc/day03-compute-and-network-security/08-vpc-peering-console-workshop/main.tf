data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "this" {
  for_each = local.vpcs

  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-vpc"
    Role = each.value.role
  })
}

resource "aws_subnet" "private" {
  for_each = local.vpcs

  availability_zone       = local.availability_zone
  cidr_block              = each.value.private_subnet_cidr
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.this[each.key].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-private-subnet"
    Role = each.value.role
  })
}

resource "aws_route_table" "private" {
  for_each = local.vpcs

  vpc_id = aws_vpc.this[each.key].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-private-rt"
    Role = each.value.role
  })
}

resource "aws_route_table_association" "private" {
  for_each = local.vpcs

  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = aws_subnet.private[each.key].id
}

resource "aws_security_group" "instance" {
  for_each = local.vpcs

  description            = "Student-managed firewall rules for ${each.key} peering tests"
  name                   = "${var.project_name}-${each.key}-instance-sg"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.this[each.key].id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-instance-sg"
    Role = each.value.role
  })
}

resource "aws_security_group" "endpoint" {
  for_each = local.vpcs

  description            = "Allow HTTPS from ${each.key} VPC instances to SSM endpoints"
  name                   = "${var.project_name}-${each.key}-ssm-endpoint-sg"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.this[each.key].id

  ingress {
    cidr_blocks = [each.value.cidr_block]
    description = "HTTPS from VPC CIDR"
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-ssm-endpoint-sg"
    Role = each.value.role
  })
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_endpoint_matrix

  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoint[each.value.vpc_key].id]
  service_name        = "com.amazonaws.${var.aws_region}.${each.value.service}"
  subnet_ids          = [aws_subnet.private[each.value.vpc_key].id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.this[each.value.vpc_key].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.value.vpc_key}-${each.value.service}-endpoint"
  })
}

resource "aws_iam_role" "ssm" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
    Version = "2012-10-17"
  })
  name = "${var.project_name}-ssm-role"

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm.name
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-instance-profile"
  role = aws_iam_role.ssm.name

  tags = local.common_tags
}

resource "aws_instance" "this" {
  for_each = local.vpcs

  ami                         = data.aws_ssm_parameter.al2023.value
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[each.key].id
  vpc_security_group_ids      = [aws_security_group.instance[each.key].id]

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-instance"
    Role = each.value.role
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_vpc_endpoint.ssm,
  ]
}

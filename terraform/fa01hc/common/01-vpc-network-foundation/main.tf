data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.subnet_map

  availability_zone       = each.key
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.subnet_map

  availability_zone       = each.key
  cidr_block              = each.value.private_cidr
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[local.first_availability_zone].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
    Tier = "public"
  })
}

resource "aws_route_table" "private" {
  for_each = local.subnet_map

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${each.key}-rt"
    Tier = "private"
  })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? aws_route_table.private : {}

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
  route_table_id         = each.value.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = each.value.id
}

resource "aws_security_group" "private_instance" {
  description            = "Private instance security group for SSM and Client VPN tests"
  name                   = "${var.project_name}-private-instance-sg"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.main.id

  ingress {
    cidr_blocks = [var.client_vpn_client_cidr_block]
    description = "ICMP from Client VPN clients"
    from_port   = -1
    protocol    = "icmp"
    to_port     = -1
  }

  ingress {
    cidr_blocks = [var.client_vpn_client_cidr_block]
    description = "SSH from Client VPN clients"
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-instance-sg"
  })
}

resource "tls_private_key" "ssh" {
  count = var.enable_ssh_key_pair ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  count = var.enable_ssh_key_pair ? 1 : 0

  key_name   = "${var.project_name}-ssh-key"
  public_key = tls_private_key.ssh[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssh-key"
  })
}

resource "local_sensitive_file" "ssh_private_key" {
  count = var.enable_ssh_key_pair ? 1 : 0

  content         = tls_private_key.ssh[0].private_key_pem
  file_permission = "0600"
  filename        = "${path.module}/${var.generated_ssh_private_key_path}"
}

resource "aws_security_group" "ssm_endpoint" {
  count = var.enable_ssm_vpc_endpoints ? 1 : 0

  description            = "SSM interface endpoint security group"
  name                   = "${var.project_name}-ssm-endpoint-sg"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.main.id

  ingress {
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from lab VPC"
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
    Name = "${var.project_name}-ssm-endpoint-sg"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = var.enable_ssm_vpc_endpoints ? local.ssm_endpoint_services : toset([])

  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ssm_endpoint[0].id]
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-endpoint"
  })
}

resource "aws_iam_role" "ssm" {
  count = var.enable_ssm_instance ? 1 : 0

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  name = "${var.project_name}-ssm-role"

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm_instance ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm[0].name
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm_instance ? 1 : 0

  name = "${var.project_name}-ssm-instance-profile"
  role = aws_iam_role.ssm[0].name

  tags = local.common_tags
}

resource "aws_instance" "private" {
  count = var.enable_ssm_instance ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023.value
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm[0].name
  instance_type               = var.instance_type
  key_name                    = var.enable_ssh_key_pair ? aws_key_pair.ssh[0].key_name : null
  subnet_id                   = aws_subnet.private[local.first_availability_zone].id
  vpc_security_group_ids      = [aws_security_group.private_instance.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-ssm-instance"
    Role = "ssm-test"
  })
}

resource "aws_security_group" "client_vpn" {
  count = var.enable_client_vpn ? 1 : 0

  description            = "Client VPN endpoint security group"
  name                   = "${var.project_name}-client-vpn-sg"
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.main.id

  egress {
    cidr_blocks = [var.vpc_cidr]
    description = "Allow Client VPN users to reach the lab VPC"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-client-vpn-sg"
  })
}

resource "aws_ec2_client_vpn_endpoint" "main" {
  count = var.enable_client_vpn ? 1 : 0

  client_cidr_block      = var.client_vpn_client_cidr_block
  description            = "${var.project_name} Client VPN"
  dns_servers            = length(var.client_vpn_dns_servers) > 0 ? var.client_vpn_dns_servers : null
  security_group_ids     = [aws_security_group.client_vpn[0].id]
  self_service_portal    = var.client_vpn_self_service_portal
  server_certificate_arn = var.client_vpn_server_certificate_arn
  split_tunnel           = var.client_vpn_split_tunnel
  transport_protocol     = var.client_vpn_transport_protocol
  vpc_id                 = aws_vpc.main.id

  authentication_options {
    root_certificate_chain_arn = var.client_vpn_root_certificate_chain_arn == null ? var.client_vpn_server_certificate_arn : var.client_vpn_root_certificate_chain_arn
    type                       = "certificate-authentication"
  }

  connection_log_options {
    enabled = false
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-client-vpn"
  })
}

resource "aws_ec2_client_vpn_network_association" "private" {
  for_each = var.enable_client_vpn ? { for key, subnet in aws_subnet.private : key => subnet.id } : {}

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  subnet_id              = each.value
}

resource "aws_ec2_client_vpn_authorization_rule" "main" {
  for_each = var.enable_client_vpn ? toset(local.client_vpn_authorization_cidr_blocks) : toset([])

  authorize_all_groups   = true
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  target_network_cidr    = each.value

  depends_on = [aws_ec2_client_vpn_network_association.private]
}

resource "aws_ec2_client_vpn_route" "additional" {
  for_each = var.enable_client_vpn ? toset(var.client_vpn_route_cidr_blocks) : toset([])

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main[0].id
  destination_cidr_block = each.value
  target_vpc_subnet_id   = aws_subnet.private[local.first_availability_zone].id

  depends_on = [aws_ec2_client_vpn_network_association.private]
}

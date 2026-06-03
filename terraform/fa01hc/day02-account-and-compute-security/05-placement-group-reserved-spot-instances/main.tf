data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

locals {
  common_tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "placement-group-reserved-spot-instances"
  }
}

resource "aws_placement_group" "spread" {
  name     = "${var.project_name}-spread"
  strategy = "spread"

  tags = local.common_tags
}

resource "aws_security_group" "spot" {
  name        = "${var.project_name}-sg"
  description = "Outbound-only security group for Spot lab"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_spot_instance_request" "worker" {
  ami                            = data.aws_ami.al2023.id
  associate_public_ip_address    = true
  instance_interruption_behavior = "terminate"
  instance_type                  = var.instance_type
  placement_group                = aws_placement_group.spread.name
  spot_type                      = "one-time"
  subnet_id                      = var.subnet_id
  vpc_security_group_ids         = [aws_security_group.spot.id]
  wait_for_fulfillment           = true

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-spot-worker"
  })
}

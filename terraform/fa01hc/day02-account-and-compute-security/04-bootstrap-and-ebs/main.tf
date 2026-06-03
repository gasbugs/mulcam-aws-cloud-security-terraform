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
    Unit      = "bootstrap-and-ebs"
  }
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "Allow outbound traffic for package installation"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  associate_public_ip_address = true
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  user_data_replace_on_change = true
  vpc_security_group_ids      = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf update -y
    dnf install -y httpd
    systemctl enable --now httpd
    echo "FA01HC bootstrap and encrypted EBS lab" > /var/www/html/index.html
  EOF

  root_block_device {
    encrypted   = true
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web"
  })
}

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web.availability_zone
  encrypted         = true
  size              = 8
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-data"
  })
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  instance_id = aws_instance.web.id
  volume_id   = aws_ebs_volume.data.id
}

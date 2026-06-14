variable "availability_zone_count" {
  description = "Number of availability zones used for public and private subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 1 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be between 1 and 3."
  }
}

variable "aws_profile" {
  description = "AWS shared config profile name. Use null or empty string when credentials are provided by environment variables."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for the VPC network foundation lab."
  type        = string
  default     = "us-east-1"
}

variable "client_vpn_client_cidr_block" {
  description = "Client IPv4 CIDR block students should use when they manually create AWS Client VPN."
  type        = string
  default     = "172.16.0.0/22"
}

variable "generated_ssh_private_key_path" {
  description = "Path, relative to this Terraform module, where the generated private key PEM file is written."
  type        = string
  default     = "generated/fa01hc-vpc-network-foundation-key.pem"
}

variable "instance_type" {
  description = "EC2 instance type for the private test instance."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-vpc-network-foundation"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the lab VPC."
  type        = string
  default     = "10.60.0.0/16"
}

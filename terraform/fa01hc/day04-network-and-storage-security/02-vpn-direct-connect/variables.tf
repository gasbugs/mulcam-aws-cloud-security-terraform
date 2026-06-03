variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for VPN resources."
  type        = string
  default     = "us-east-1"
}

variable "customer_gateway_ip" {
  description = "Public IP address of the on-premises customer gateway."
  type        = string
  default     = "203.0.113.10"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-vpn"
}

variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for VPC peering resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-vpc-peering"
}

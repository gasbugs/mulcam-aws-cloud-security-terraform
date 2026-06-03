variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for EC2 placement and Spot resources."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Spot instance type."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-spot"
}

variable "subnet_id" {
  description = "Existing subnet ID for the Spot instance."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID for the Spot instance security group."
  type        = string
}

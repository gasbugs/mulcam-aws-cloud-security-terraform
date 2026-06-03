variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for EC2 and EBS resources."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the bootstrap lab."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-bootstrap-ebs"
}

variable "vpc_id" {
  description = "Existing VPC ID for the EC2 instance."
  type        = string
}

variable "subnet_id" {
  description = "Existing subnet ID for the EC2 instance."
  type        = string
}

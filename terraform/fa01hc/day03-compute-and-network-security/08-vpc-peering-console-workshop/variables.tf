variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for the Network Firewall inspection CLI workshop."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type used for SSM-based connectivity tests."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-inspection-firewall-cli"
}

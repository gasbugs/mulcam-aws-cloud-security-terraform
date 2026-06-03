variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region used for the overview check."
  type        = string
  default     = "us-east-1"
}

variable "analyzer_name" {
  description = "Name for the IAM Access Analyzer."
  type        = string
  default     = "fa01hc-account-access-analyzer"
}

variable "aws_profile" {
  description = "AWS CLI profile to use. Set to null to use the default provider credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for IAM Access Analyzer."
  type        = string
  default     = "us-east-1"
}

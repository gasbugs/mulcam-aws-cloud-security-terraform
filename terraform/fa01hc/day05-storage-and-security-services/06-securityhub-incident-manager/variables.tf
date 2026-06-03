variable "aws_region" {
  description = "AWS Region where Security Hub and Incident Manager are configured."
  type        = string
  default     = "us-east-1"
}

variable "enable_default_standards" {
  description = "Whether Security Hub enables default standards when the account is created."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name used in tags and resource names."
  type        = string
  default     = "training"
}

variable "project_name" {
  description = "Project name used as the prefix for lab resources."
  type        = string
  default     = "fa01hc-securityhub"
}

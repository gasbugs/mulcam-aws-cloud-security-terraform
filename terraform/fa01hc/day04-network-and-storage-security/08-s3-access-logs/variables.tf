variable "aws_region" {
  description = "AWS Region where the lab resources are created."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in tags and resource names."
  type        = string
  default     = "training"
}

variable "project_name" {
  description = "Project name used as the prefix for lab resources."
  type        = string
  default     = "fa01hc-s3-access-logs"
}

variable "aws_region" {
  description = "AWS Region where AWS Config is enabled."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in tags and resource names."
  type        = string
  default     = "training"
}

variable "include_global_resource_types" {
  description = "Whether AWS Config records supported global resource types in this Region."
  type        = bool
  default     = true
}

variable "managed_rule_identifiers" {
  description = "AWS managed Config rule identifiers used for compliance demonstrations."
  type        = set(string)
  default = [
    "EC2_SECURITY_GROUP_ATTACHED_TO_ENI",
    "IAM_ROOT_ACCESS_KEY_CHECK",
    "S3_BUCKET_PUBLIC_READ_PROHIBITED",
  ]
}

variable "project_name" {
  description = "Project name used as the prefix for lab resources."
  type        = string
  default     = "fa01hc-aws-config"
}

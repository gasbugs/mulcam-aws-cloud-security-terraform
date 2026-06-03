variable "aws_region" {
  description = "AWS Region where GuardDuty is enabled."
  type        = string
  default     = "us-east-1"
}

variable "enable_ebs_malware_protection" {
  description = "Whether to enable GuardDuty EBS malware protection."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name used in tags and resource names."
  type        = string
  default     = "training"
}

variable "finding_publishing_frequency" {
  description = "Frequency at which GuardDuty publishes updated findings."
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition = contains([
      "FIFTEEN_MINUTES",
      "ONE_HOUR",
      "SIX_HOURS",
    ], var.finding_publishing_frequency)
    error_message = "Finding publishing frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "project_name" {
  description = "Project name used as the prefix for lab resources."
  type        = string
  default     = "fa01hc-guardduty"
}

locals {
  common_tags = {
    Course      = "FA01HC"
    Environment = var.environment
    Lab         = "day05-aws-config-compliance"
    ManagedBy   = "Terraform"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}

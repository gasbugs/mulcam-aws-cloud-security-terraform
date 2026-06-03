locals {
  common_tags = {
    Course      = "FA01HC"
    Environment = var.environment
    Lab         = "day05-securityhub-incident-manager"
    ManagedBy   = "Terraform"
  }

  name_prefix        = "${var.project_name}-${var.environment}"
  response_plan_name = "${var.project_name}-${var.environment}-response-plan"
}

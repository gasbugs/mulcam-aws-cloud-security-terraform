locals {
  common_tags = {
    Course      = "FA01HC"
    Environment = var.environment
    Lab         = "day05-guardduty-threat-detection"
    ManagedBy   = "Terraform"
  }
}

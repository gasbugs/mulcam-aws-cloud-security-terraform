resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = var.analyzer_name
  type          = "ACCOUNT"

  tags = {
    Course    = "FA01HC"
    ManagedBy = "Terraform"
    Unit      = "iam-access-analyzer"
  }
}

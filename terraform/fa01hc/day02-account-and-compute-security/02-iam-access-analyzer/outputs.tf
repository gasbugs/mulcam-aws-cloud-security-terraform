output "analyzer_arn" {
  description = "ARN of the IAM Access Analyzer."
  value       = aws_accessanalyzer_analyzer.account.arn
}

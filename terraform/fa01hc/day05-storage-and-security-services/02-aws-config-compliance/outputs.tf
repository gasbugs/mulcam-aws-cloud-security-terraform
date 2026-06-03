output "config_bucket_name" {
  description = "Name of the S3 bucket used by AWS Config delivery channel."
  value       = aws_s3_bucket.config.bucket
}

output "config_rule_names" {
  description = "Names of the AWS Config managed rules created for the lab."
  value       = [for rule in aws_config_config_rule.managed : rule.name]
}

output "recorder_name" {
  description = "Name of the AWS Config configuration recorder."
  value       = aws_config_configuration_recorder.main.name
}

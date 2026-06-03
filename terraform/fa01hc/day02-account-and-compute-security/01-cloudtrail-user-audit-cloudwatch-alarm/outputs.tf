output "cloudtrail_bucket_name" {
  description = "S3 bucket receiving CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_name" {
  description = "Name of the created CloudTrail trail."
  value       = aws_cloudtrail.main.name
}

output "failed_login_alarm_name" {
  description = "CloudWatch alarm for failed console login events."
  value       = aws_cloudwatch_metric_alarm.failed_console_login.alarm_name
}

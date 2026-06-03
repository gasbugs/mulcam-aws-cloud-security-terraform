output "log_bucket_name" {
  description = "Name of the S3 bucket that receives server access logs."
  value       = aws_s3_bucket.logs.bucket
}

output "log_prefix" {
  description = "Prefix where S3 server access logs are delivered."
  value       = aws_s3_bucket_logging.source.target_prefix
}

output "source_bucket_name" {
  description = "Name of the source S3 bucket with server access logging enabled."
  value       = aws_s3_bucket.source.bucket
}

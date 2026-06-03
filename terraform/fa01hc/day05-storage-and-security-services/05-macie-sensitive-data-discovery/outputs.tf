output "classification_job_id" {
  description = "ID of the Macie classification job."
  value       = aws_macie2_classification_job.sample.job_id
}

output "macie_status" {
  description = "Macie account status for this Region."
  value       = aws_macie2_account.main.status
}

output "sample_bucket_name" {
  description = "Name of the S3 bucket scanned by the Macie classification job."
  value       = aws_s3_bucket.sample.bucket
}

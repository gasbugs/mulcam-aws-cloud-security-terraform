output "account_id" {
  description = "AWS account ID resolved by the provider."
  value       = data.aws_caller_identity.current.account_id
}

output "partition" {
  description = "AWS partition, such as aws or aws-cn."
  value       = data.aws_partition.current.partition
}

output "region" {
  description = "AWS region resolved by the provider."
  value       = data.aws_region.current.name
}

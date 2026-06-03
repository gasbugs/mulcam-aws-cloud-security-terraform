output "app_vpc_id" {
  description = "ID of the app VPC."
  value       = aws_vpc.app.id
}

output "peering_connection_id" {
  description = "ID of the VPC peering connection."
  value       = aws_vpc_peering_connection.main.id
}

output "shared_vpc_id" {
  description = "ID of the shared services VPC."
  value       = aws_vpc.shared.id
}

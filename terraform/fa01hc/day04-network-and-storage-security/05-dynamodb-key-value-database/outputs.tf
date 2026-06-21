output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.users_table.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.users_table.arn
}

output "dynamodb_vpc_endpoint_id" {
  description = "The ID of the DynamoDB Gateway VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "dynamodb_vpc_endpoint_route_table_ids" {
  description = "Route table IDs associated with the DynamoDB Gateway VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.route_table_ids
}

output "ec2_private_key_path" {
  description = "Path to the SSH private key for the DynamoDB test EC2 instance"
  value       = local_file.ec2_private_key.filename
}

output "ec2_public_dns" {
  description = "Public DNS name of the DynamoDB endpoint test EC2 instance"
  value       = aws_instance.dynamodb_client.public_dns
}

output "ec2_public_ip" {
  description = "Public IP address of the DynamoDB endpoint test EC2 instance"
  value       = aws_instance.dynamodb_client.public_ip
}

output "private_subnet_ids" {
  description = "Private subnet IDs created for DynamoDB endpoint routing"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "vpc_id" {
  description = "The ID of the VPC that contains the DynamoDB Gateway Endpoint"
  value       = aws_vpc.this.id
}

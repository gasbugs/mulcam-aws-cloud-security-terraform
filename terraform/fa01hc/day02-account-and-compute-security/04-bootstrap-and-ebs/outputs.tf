output "data_volume_id" {
  description = "ID of the encrypted data EBS volume."
  value       = aws_ebs_volume.data.id
}

output "instance_id" {
  description = "ID of the bootstrap EC2 instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the bootstrap EC2 instance."
  value       = aws_instance.web.public_ip
}

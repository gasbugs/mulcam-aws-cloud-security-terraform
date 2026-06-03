output "placement_group_name" {
  description = "Name of the EC2 placement group."
  value       = aws_placement_group.spread.name
}

output "spot_instance_id" {
  description = "Instance ID fulfilled by the Spot request."
  value       = aws_spot_instance_request.worker.spot_instance_id
}

output "spot_request_id" {
  description = "Spot instance request ID."
  value       = aws_spot_instance_request.worker.id
}

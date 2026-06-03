output "egress_only_internet_gateway_id" {
  description = "ID of the IPv6 egress-only internet gateway."
  value       = aws_egress_only_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "customer_gateway_id" {
  description = "ID of the customer gateway."
  value       = aws_customer_gateway.main.id
}

output "vpn_connection_id" {
  description = "ID of the site-to-site VPN connection."
  value       = aws_vpn_connection.main.id
}

output "vpn_gateway_id" {
  description = "ID of the VPN gateway."
  value       = aws_vpn_gateway.main.id
}

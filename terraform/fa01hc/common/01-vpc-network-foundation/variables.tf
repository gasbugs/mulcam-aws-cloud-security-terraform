variable "availability_zone_count" {
  description = "Number of availability zones used for public and private subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 1 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be between 1 and 3."
  }
}

variable "aws_profile" {
  description = "AWS shared config profile name. Use null or empty string when credentials are provided by environment variables."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for the VPC network foundation lab."
  type        = string
  default     = "us-east-1"
}

variable "client_vpn_authorization_cidr_blocks" {
  description = "CIDR blocks that Client VPN users are authorized to reach. Leave empty to use vpc_cidr."
  type        = list(string)
  default     = []
}

variable "client_vpn_client_cidr_block" {
  description = "Client IPv4 CIDR block assigned to AWS Client VPN users."
  type        = string
  default     = "172.16.0.0/22"
}

variable "client_vpn_dns_servers" {
  description = "Optional DNS servers pushed to Client VPN users. Leave empty to use AWS defaults."
  type        = list(string)
  default     = []
}

variable "client_vpn_root_certificate_chain_arn" {
  description = "ACM ARN of the client root certificate chain for mutual certificate authentication."
  type        = string
  default     = null
}

variable "client_vpn_route_cidr_blocks" {
  description = "Additional Client VPN route table destinations. The VPC CIDR is available through the subnet association."
  type        = list(string)
  default     = []
}

variable "client_vpn_self_service_portal" {
  description = "Self-service portal mode for the Client VPN endpoint."
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "enabled"], var.client_vpn_self_service_portal)
    error_message = "client_vpn_self_service_portal must be disabled or enabled."
  }
}

variable "client_vpn_server_certificate_arn" {
  description = "ACM ARN of the server certificate used by the Client VPN endpoint."
  type        = string
  default     = null
}

variable "client_vpn_split_tunnel" {
  description = "Whether Client VPN uses split tunnel mode."
  type        = bool
  default     = true
}

variable "client_vpn_transport_protocol" {
  description = "Transport protocol for the Client VPN endpoint."
  type        = string
  default     = "udp"

  validation {
    condition     = contains(["tcp", "udp"], var.client_vpn_transport_protocol)
    error_message = "client_vpn_transport_protocol must be tcp or udp."
  }
}

variable "enable_client_vpn" {
  description = "Whether to create AWS Client VPN endpoint resources. Certificate ARNs are required when true."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for outbound internet access from private subnets."
  type        = bool
  default     = true
}

variable "enable_ssh_key_pair" {
  description = "Whether to generate a TLS private key and register an EC2 key pair for SSH tests."
  type        = bool
  default     = true
}

variable "enable_ssm_instance" {
  description = "Whether to create a private EC2 instance for Session Manager and network tests."
  type        = bool
  default     = true
}

variable "enable_ssm_vpc_endpoints" {
  description = "Whether to create SSM interface endpoints. Useful when testing Session Manager without NAT."
  type        = bool
  default     = false
}

variable "generated_ssh_private_key_path" {
  description = "Path, relative to this Terraform module, where the generated private key PEM file is written."
  type        = string
  default     = "generated/fa01hc-vpc-network-foundation-key.pem"
}

variable "instance_type" {
  description = "EC2 instance type for the private Session Manager test instance."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fa01hc-vpc-network-foundation"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the lab VPC."
  type        = string
  default     = "10.60.0.0/16"
}

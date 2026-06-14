aws_region               = "us-east-1"
availability_zone_count  = 2
enable_client_vpn        = false
enable_nat_gateway       = true
enable_ssm_instance      = true
enable_ssm_vpc_endpoints = false
enable_ssh_key_pair      = true
instance_type            = "t3.micro"
project_name             = "fa01hc-vpc-network-foundation"
vpc_cidr                 = "10.60.0.0/16"

# Client VPN 실습을 진행할 때 ACM 인증서 ARN을 넣고 enable_client_vpn을 true로 변경합니다.
client_vpn_server_certificate_arn     = null
client_vpn_root_certificate_chain_arn = null

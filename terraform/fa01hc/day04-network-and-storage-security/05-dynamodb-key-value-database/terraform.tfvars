#######################################
# 프로바이더 및 환경 정보
aws_region  = "us-east-1"
aws_profile = "default"
environment = "Production"
owner       = "TeamA"

#######################################
# VPC Endpoint 변수
vpc_name = "dynamodb-endpoint-vpc"
vpc_cidr = "10.20.0.0/16"
private_subnets = {
  private_1 = {
    availability_zone = "us-east-1a"
    cidr_block        = "10.20.1.0/24"
  }
  private_2 = {
    availability_zone = "us-east-1b"
    cidr_block        = "10.20.2.0/24"
  }
}
public_subnet = {
  availability_zone = "us-east-1a"
  cidr_block        = "10.20.10.0/24"
}
allowed_ssh_cidr = "0.0.0.0/0"
instance_type    = "t3.micro"
instance_name    = "dynamodb_client"

#######################################
# DynamoDB 변수
table_name = "Users"
# billing_mode = PROVISIONED 사용 시 활성화
# read_capacity  = 5
# write_capacity = 5
# project        = "UserManagement"

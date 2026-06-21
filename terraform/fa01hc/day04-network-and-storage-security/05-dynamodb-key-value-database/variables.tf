#######################################
# 프로바이더 및 환경 정보
variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "environment" {
  description = "The environment of the RDS instance (e.g., Production, Staging)"
  type        = string
  default     = "Production"
}

variable "owner" {
  description = "이 리소스를 관리하는 담당자"
  type        = string
  default     = "TeamA"
}

#######################################
# VPC Endpoint 변수
variable "vpc_name" {
  description = "DynamoDB Gateway Endpoint를 생성할 VPC 이름"
  type        = string
  default     = "dynamodb-endpoint-vpc"
}

variable "vpc_cidr" {
  description = "DynamoDB Gateway Endpoint VPC CIDR 블록"
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr은 유효한 CIDR 형식이어야 합니다."
  }
}

variable "private_subnets" {
  description = "DynamoDB Gateway Endpoint route table을 연결할 private subnet 설정"
  type = map(object({
    availability_zone = string
    cidr_block        = string
  }))
  default = {
    private_1 = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.20.1.0/24"
    }
    private_2 = {
      availability_zone = "us-east-1b"
      cidr_block        = "10.20.2.0/24"
    }
  }
}

variable "public_subnet" {
  description = "DynamoDB Endpoint 접근 테스트용 EC2를 배치할 public subnet 설정"
  type = object({
    availability_zone = string
    cidr_block        = string
  })
  default = {
    availability_zone = "us-east-1a"
    cidr_block        = "10.20.10.0/24"
  }
}

variable "allowed_ssh_cidr" {
  description = "DynamoDB 테스트 EC2 SSH 접근 허용 CIDR"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr은 유효한 CIDR 형식이어야 합니다."
  }
}

variable "instance_type" {
  description = "DynamoDB endpoint 테스트용 EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "DynamoDB endpoint 테스트용 EC2 Name 태그"
  type        = string
  default     = "dynamodb_client"
}

#######################################
# DynamoDB 변수
variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "Users"
}

# billing_mode = PROVISIONED 사용 시 활성화 (현재는 PAY_PER_REQUEST 모드로 불필요)
# variable "read_capacity" {
#   description = "The read capacity units for the DynamoDB table"
#   type        = number
#   default     = 5
# }

# variable "write_capacity" {
#   description = "The write capacity units for the DynamoDB table"
#   type        = number
#   default     = 5
# }

# 프로젝트 태그 활용 시 활성화
# variable "project" {
#   description = "The project tag for the DynamoDB table"
#   type        = string
#   default     = "UserManagement"
# }

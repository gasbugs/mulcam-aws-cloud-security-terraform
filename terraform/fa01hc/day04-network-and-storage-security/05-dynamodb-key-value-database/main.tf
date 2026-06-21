#######################################
# VPC — DynamoDB Gateway Endpoint 실습용 사설 네트워크
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "${var.vpc_name}-${each.key}"
  }
}

resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-${each.key}-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = var.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet.cidr_block
  availability_zone       = var.public_subnet.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#######################################
# DynamoDB 테이블 — 사용자 정보 저장
resource "aws_dynamodb_table" "users_table" {
  name = var.table_name

  # 요금제 설정
  # PROVISIONED: 고정된 읽기/쓰기 처리량을 미리 지정 (read_capacity, write_capacity 활성화 필요)
  # PAY_PER_REQUEST: 요청 건수만큼만 과금 — 트래픽이 불규칙하거나 학습 환경에 적합
  billing_mode = "PAY_PER_REQUEST"
  # read_capacity  = var.read_capacity
  # write_capacity = var.write_capacity

  hash_key  = "UserId"    # 파티션 키(Partition Key) — 데이터를 분산 저장하는 기준
  range_key = "CreatedAt" # 정렬 키(Sort Key) — 같은 파티션 내에서 데이터 정렬 기준

  attribute {
    name = "UserId"
    type = "S" # String 타입
  }

  attribute {
    name = "CreatedAt"
    type = "S" # String 타입 — ISO 8601 형식 문자열로 저장 (예: "2024-06-01T00:00:00")
  }

  point_in_time_recovery {
    enabled = true
  }

  # -----------------------------------------------------------------------
  # GSI(Global Secondary Index, 글로벌 보조 인덱스) — 나중에 실습 예정
  # -----------------------------------------------------------------------
  # 기본 키(UserId + CreatedAt) 외의 속성으로도 효율적인 쿼리를 가능하게 하는 기능.
  # 예) Username으로 사용자를 직접 검색하고 싶을 때 테이블 전체 스캔(Scan) 대신
  #     GSI를 통해 인덱스 조회(Query)로 빠르게 찾을 수 있다.
  #
  # 주요 옵션 설명:
  #   name            — 인덱스 이름 (쿼리 시 IndexName 파라미터에 지정)
  #   key_schema      — 이 인덱스의 파티션 키(HASH) / 정렬 키(RANGE) 설정
  #                     ※ GSI 내부에서는 hash_key/range_key가 만료됨 → key_schema 블록 사용
  #   projection_type — 인덱스에 복사할 속성 범위
  #                     ALL      : 모든 속성 복사 (조회 편리, 스토리지 비용↑)
  #                     KEYS_ONLY: 기본 키 + 인덱스 키만 복사 (최소 비용)
  #                     INCLUDE  : 지정한 속성만 추가 복사
  #
  # LSI(Local Secondary Index)와의 차이:
  #   GSI — 파티션 키가 달라도 됨, 테이블 생성 후에도 추가/삭제 가능
  #   LSI — 파티션 키가 기본 테이블과 동일해야 함, 테이블 생성 시에만 설정 가능
  # -----------------------------------------------------------------------
  # global_secondary_index {
  #   name            = "UsernameIndex" # 인덱스 이름 (쿼리 시 IndexName으로 참조)
  #   projection_type = "ALL"           # 모든 테이블 속성을 인덱스에 복사
  #
  #   key_schema {
  #     attribute_name = "Username"     # 이 인덱스의 파티션 키 — Username으로 직접 검색 가능
  #     key_type       = "HASH"
  #   }
  # }

  # GSI 활성화 시 아래 attribute 블록도 함께 주석 해제
  # attribute {
  #   name = "Username"
  #   type = "S" # 'Username'은 문자열(String) 타입으로 보조 인덱스의 해시 키에 사용
  # }

  tags = {
    Name = var.table_name # 테이블 이름 태그 — AWS 콘솔에서 리소스 식별에 사용
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([for route_table in aws_route_table.private : route_table.id], [aws_route_table.public.id])

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "dynamodb:*"
        Resource = [
          aws_dynamodb_table.users_table.arn,
          "${aws_dynamodb_table.users_table.arn}/index/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.table_name}-dynamodb-endpoint"
  }
}

resource "aws_dynamodb_resource_policy" "users_table" {
  resource_arn = aws_dynamodb_table.users_table.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyDataAccessOutsideDynamoDBVpcEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.users_table.arn,
          "${aws_dynamodb_table.users_table.arn}/index/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.dynamodb.id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "ec2_dynamodb_client" {
  name = "${var.table_name}-dynamodb-client-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.table_name}-dynamodb-client-role"
  }
}

resource "aws_iam_role_policy" "ec2_dynamodb_client" {
  name = "${var.table_name}-dynamodb-client-policy"
  role = aws_iam_role.ec2_dynamodb_client.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:TransactGetItems",
          "dynamodb:TransactWriteItems",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.users_table.arn,
          "${aws_dynamodb_table.users_table.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_dynamodb_client" {
  name = "${var.table_name}-dynamodb-client-profile"
  role = aws_iam_role.ec2_dynamodb_client.name
}

resource "random_integer" "key_suffix" {
  min = 1000
  max = 9999
}

resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ec2_private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.root}/ec2-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "ec2" {
  key_name   = "dynamodb-client-${random_integer.key_suffix.result}"
  public_key = tls_private_key.ec2.public_key_openssh
}

resource "aws_security_group" "ec2" {
  name_prefix = "dynamodb-client-"
  description = "Security group for DynamoDB endpoint test EC2"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "dynamodb-client-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow SSH for DynamoDB endpoint test"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "dynamodb_client" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_dynamodb_client.name
  key_name                    = aws_key_pair.ec2.key_name
  associate_public_ip_address = true

  tags = {
    Name = var.instance_name
  }
}

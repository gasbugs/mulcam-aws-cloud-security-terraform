# FA01HC 강의 타임테이블 및 Terraform 실습 구성

과정 링크: <https://m.multicampus.com/course/crsDetail?corsCd=FA01HC>

## 구성 요약

- 총 5일, 34개 단원
- Terraform 루트 프로젝트 31개
- 개념/토론형 가이드 3개
- 최종 실습 구조: `terraform/fa01hc/`
- 전체 정적 검증: `make check` 결과 `total=31 passed=31 failed=0`
- 전체 비파괴 plan 검증: `make plan-check` 결과 `total=31 planable=31 failed=0`

## 운영 원칙

- 강의 순서는 이 문서의 시간표를 기준으로 진행합니다.
- 실제 리소스 테스트는 단원별로 짧게 실행합니다.
- 리소스를 만든 테스트는 반드시 `CONFIRM_APPLY_DESTROY=YES make lifecycle-apply-destroy LAB=<path>`로 실행합니다.
- lifecycle 스크립트는 `apply` 이후 `destroy`를 실행하고, Terraform state에 관리 리소스가 남아 있는지 확인합니다.
- `terraform.tfvars`는 강의용 기본값으로 의도적으로 유지합니다.

## Day 1: 클라우드와 보안 / AWS 계정 관리

| 시간 | 교시 | 챕터 | 단원 | 구성 | 프로젝트 경로 | 실습 내용 |
| --- | --- | --- | --- | --- | --- | --- |
| 09:30-10:30 | 1교시 | 클라우드와 보안 | 클라우드 서비스 개념 | Guide | `terraform/fa01hc/day01-cloud-and-account-security/01-cloud-service-concepts` | 클라우드 서비스 모델, 책임 공유 모델, AWS 기본 구조 안내 |
| 10:30-11:30 | 2교시 | 클라우드와 보안 | 클라우드 보안 이해 | Guide | `terraform/fa01hc/day01-cloud-and-account-security/02-cloud-security-fundamentals` | 클라우드 보안 핵심 개념, 계정/네트워크/데이터 보호 관점 정리 |
| 12:30-13:30 | 3교시 | 클라우드와 보안 | AWS 환경에서 사고 대응 | Guide | `terraform/fa01hc/day01-cloud-and-account-security/03-aws-incident-response-overview` | AWS 사고 대응 흐름, 로그 수집, 격리, 분석, 복구 토론 |
| 13:30-14:30 | 4교시 | AWS 계정 관리 | AWS 서비스 살펴보기 | Terraform | `terraform/fa01hc/day01-cloud-and-account-security/04-aws-services-overview` | AWS provider, caller identity, region, partition 확인 |
| 14:30-15:30 | 5교시 | AWS 계정 관리 | AWS 계정 구성, 계정 보호 및 사용자 접근 제어 | Terraform | `terraform/fa01hc/day01-cloud-and-account-security/05-account-protection-and-access-control` | IAM 사용자, 그룹, 액세스 키, 관리형 정책 연결 |
| 15:30-16:30 | 6교시 | AWS 계정 관리 | AWS IAM 기본 | Terraform | `terraform/fa01hc/day01-cloud-and-account-security/06-iam-basics` | IAM 사용자, 정책 문서, 권한 연결 기본 실습 |
| 16:30-17:30 | 7교시 | AWS 계정 관리 | IAM Identity Center를 활용한 SSO 유저 관리 | Terraform | `terraform/fa01hc/day01-cloud-and-account-security/07-iam-identity-center-sso` | Identity Center 사용자, 그룹, 권한 세트, 계정 할당 |

## Day 2: AWS 계정 관리 / AWS 컴퓨팅 서비스 보안

| 시간 | 교시 | 챕터 | 단원 | 구성 | 프로젝트 경로 | 실습 내용 |
| --- | --- | --- | --- | --- | --- | --- |
| 09:30-10:30 | 1교시 | AWS 계정 관리 | CloudTrail 이벤트를 활용한 유저 감사와 CloudWatch 경보 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/01-cloudtrail-user-audit-cloudwatch-alarm` | CloudTrail, S3 로그 버킷, CloudWatch Logs, 실패 로그인 metric/alarm |
| 10:30-11:30 | 2교시 | AWS 계정 관리 | IAM 액세스 분석기 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/02-iam-access-analyzer` | IAM Access Analyzer 활성화와 외부 접근 분석 기반 마련 |
| 12:30-13:30 | 3교시 | AWS 컴퓨팅 서비스 보안 | EC2를 활용한 가상머신 구성과 활용 이해 / 공인 IP 이해 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/03-ec2-virtual-machine-and-public-ip` | EC2 인스턴스, AMI, 공인 IP, 기본 보안 그룹 실습 |
| 13:30-14:30 | 4교시 | AWS 컴퓨팅 서비스 보안 | 부트스트랩 / EBS 기본 기능 이해 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/04-bootstrap-and-ebs` | EC2 user data, encrypted root volume, encrypted EBS volume attach |
| 14:30-15:30 | 5교시 | AWS 컴퓨팅 서비스 보안 | 배치 그룹을 활용한 스케줄링 전략 이해 / 예약·스팟 인스턴스를 활용한 비용 절감 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/05-placement-group-reserved-spot-instances` | Placement Group, Spot Instance Request, 비용 최적화 개념 |
| 15:30-16:30 | 6교시 | AWS 컴퓨팅 서비스 보안 | 람다와 API 게이트웨이를 활용한 서버리스 컴퓨팅 이해 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/06-lambda-api-gateway-serverless` | Lambda 함수, API Gateway, IAM 실행 역할 |
| 16:30-17:30 | 7교시 | AWS 컴퓨팅 서비스 보안 | ECS/EKS를 활용한 컨테이너 컴퓨팅 이해 | Terraform | `terraform/fa01hc/day02-account-and-compute-security/07-ecs-eks-container-computing` | ECS Fargate, ALB, Task Definition, Service, VPC |

## Day 3: AWS 컴퓨팅 서비스 보안 / AWS 네트워크 인프라 보안

| 시간 | 교시 | 챕터 | 단원 | 구성 | 프로젝트 경로 | 실습 내용 |
| --- | --- | --- | --- | --- | --- | --- |
| 09:30-10:30 | 1교시 | AWS 컴퓨팅 서비스 보안 | S3를 활용한 저장소 구성과 웹 정적 컨텐츠 서비스 이해 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/01-s3-static-content-service` | S3 정적 웹 콘텐츠, 버킷 정책, 웹 객체 업로드 |
| 10:30-11:30 | 2교시 | AWS 네트워크 인프라 보안 | VPC를 활용한 가상 네트워크 구성 이해 / 보안 그룹·NACLs를 활용한 보호 이해 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/02-vpc-security-group-nacl` | VPC, Subnet, Security Group, NACL, EC2 네트워크 보호 |
| 12:30-13:30 | 3교시 | AWS 네트워크 인프라 보안 | 베스쳔 호스트 / NAT 게이트웨이와 Egress-Only Internet Gateway | Terraform | `terraform/fa01hc/day03-compute-and-network-security/03-bastion-nat-egress-only-gateway` | Bastion 보안 그룹, NAT Gateway, IPv6 Egress-only IGW, 라우팅 |
| 13:30-14:30 | 4교시 | AWS 네트워크 인프라 보안 | VPC 엔드포인트 / VPC 라우팅 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/04-vpc-endpoint-and-routing` | VPC module, Gateway/Interface Endpoint, Route Table, Endpoint Policy |
| 14:30-15:30 | 5교시 | AWS 네트워크 인프라 보안 | CloudFront와 Route53 이해 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/05-cloudfront-route53` | S3 origin, CloudFront distribution, Route53 연동 모듈 |
| 15:30-16:30 | 6교시 | AWS 네트워크 인프라 보안 | AWS WAF를 활용한 웹 애플리케이션 보호 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/06-aws-waf-web-application-protection` | CloudFront, S3, AWS WAF Web ACL, 관리형 룰 |
| 16:30-17:30 | 7교시 | AWS 네트워크 인프라 보안 | VPC 피어링를 활용한 VPC 간 연결 | Terraform | `terraform/fa01hc/day03-compute-and-network-security/07-vpc-peering` | 두 VPC 생성, VPC Peering Connection, 라우팅 연결 |

## Day 4: AWS 네트워크 인프라 보안 / 저장소 보안

| 시간 | 교시 | 챕터 | 단원 | 구성 | 프로젝트 경로 | 실습 내용 |
| --- | --- | --- | --- | --- | --- | --- |
| 09:30-10:30 | 1교시 | AWS 네트워크 인프라 보안 | 로드밸런서와 오토스케일링를 활용한 가상머신 가용성 구성 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/01-load-balancer-autoscaling-availability` | ALB, Target Group, Launch Template, Auto Scaling Group |
| 10:30-11:30 | 2교시 | AWS 네트워크 인프라 보안 | VPN과 다이렉트 커넥트 이해 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/02-vpn-direct-connect` | VPC, Virtual Private Gateway, Customer Gateway, Site-to-Site VPN |
| 12:30-13:30 | 3교시 | 저장소 보안 | Aurora와 RDS를 활용한 관계형 데이터베이스 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/03-aurora-rds-relational-database` | Aurora/RDS, DB Subnet Group, 보안 그룹, 접속용 EC2 |
| 13:30-14:30 | 4교시 | 저장소 보안 | DynamoDB를 활용한 Key-Value 데이터베이스 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/04-dynamodb-key-value-database` | DynamoDB Table, IAM 권한, Python 연결 예제 |
| 14:30-15:30 | 5교시 | 저장소 보안 | ElastiCache를 활용한 캐싱 서버 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/05-elasticache-caching-server` | ElastiCache/Valkey, 캐시 접근용 EC2, DynamoDB 연계 예제 |
| 15:30-16:30 | 6교시 | 저장소 보안 | KMS 서비스를 활용한 키 구성과 저장소 암호화 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/06-kms-storage-encryption` | KMS Key, S3 암호화, EC2 IAM role, 암호화 객체 접근 |
| 16:30-17:30 | 7교시 | 저장소 보안 | S3 액세스 로그 기록 | Terraform | `terraform/fa01hc/day04-network-and-storage-security/07-s3-access-logs` | Source/Log S3 bucket, Server Access Logging, 로그 전달 정책 |

## Day 5: 저장소 보안 / AWS 보안 서비스 이해

| 시간 | 교시 | 챕터 | 단원 | 구성 | 프로젝트 경로 | 실습 내용 |
| --- | --- | --- | --- | --- | --- | --- |
| 09:30-10:30 | 1교시 | 저장소 보안 | Secret Manager를 활용한 비밀 정보 관리 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/01-secrets-manager-secret-management` | Secrets Manager, Rotation Lambda, EC2 접근 권한 |
| 10:30-11:30 | 2교시 | AWS 보안 서비스 이해 | AWS Config를 활용한 규정 준수 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance` | AWS Config Recorder, Delivery Channel, S3 delivery bucket, Managed Rules |
| 12:30-13:30 | 3교시 | AWS 보안 서비스 이해 | Inspector를 활용한 취약성 관리 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/03-inspector-vulnerability-management` | Inspector v2 활성화, EC2/ECR/Lambda 스캔, ECR Enhanced Scanning |
| 13:30-14:30 | 4교시 | AWS 보안 서비스 이해 | GuardDuty를 활용한 악성코드 탐지 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/04-guardduty-threat-detection` | GuardDuty Detector, EBS Malware Protection |
| 14:30-15:30 | 5교시 | AWS 보안 서비스 이해 | Macie를 활용한 민감 정보 탐지 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/05-macie-sensitive-data-discovery` | Macie 활성화, S3 샘플 버킷, one-time classification job |
| 15:30-16:30 | 6교시 | AWS 보안 서비스 이해 | SecurityHub를 활용한 보안 상태 통합 보기, Incident Manager를 활용한 대응 계획 수립 | Terraform | `terraform/fa01hc/day05-storage-and-security-services/06-securityhub-incident-manager` | Security Hub 표준 구독, EventBridge, SNS, Incident Manager Response Plan |

## 비용 및 삭제 주의 단원

| 단원 | 주의 리소스 | 권장 운영 |
| --- | --- | --- |
| `day03/03-bastion-nat-egress-only-gateway` | NAT Gateway, EIP | 짧게 apply 후 즉시 destroy |
| `day03/04-vpc-endpoint-and-routing` | NAT Gateway, Interface Endpoint, VPN 관련 리소스 | 강의 전 별도 리허설 필수 |
| `day04/01-load-balancer-autoscaling-availability` | ALB, ASG, EC2 | 테스트 후 즉시 destroy |
| `day04/03-aurora-rds-relational-database` | Aurora/RDS, EC2 | 생성 시간이 길 수 있으므로 사전 리허설 |
| `day04/05-elasticache-caching-server` | ElastiCache, EC2 | 테스트 후 즉시 destroy |
| `day05/03-inspector-vulnerability-management` | Inspector, ECR Enhanced Scanning | 계정 상태와 과금 정책 확인 |
| `day05/04-guardduty-threat-detection` | GuardDuty | 계정/리전 단위 활성화 주의 |
| `day05/05-macie-sensitive-data-discovery` | Macie, S3 classification job | 민감 정보 탐지 비용 주의 |
| `day05/06-securityhub-incident-manager` | Security Hub, Incident Manager | 기존 계정 설정과 충돌 여부 확인 |

## 실행 명령

```bash
make list
make roots
make check
make plan-check
```

단원별 리소스 생성과 삭제 검증:

```bash
CONFIRM_APPLY_DESTROY=YES make lifecycle-apply-destroy LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

특정 AWS CLI profile을 강제로 쓰는 경우:

```bash
FA01HC_AWS_PROFILE=my-profile make plan-check
```

# FA01HC Workshop Account Compatibility

검토 대상:

- Credentials CSV: 워크숍 계정 배포 CSV, 레포에는 포함하지 않음
- IAM Policy: `TerraformWorkshop-Restricted-us-east-1.json`, 레포에는 포함하지 않음

## 결론

이 워크숍 계정으로 **모든 FA01HC Terraform 실습을 그대로 진행하기는 어렵습니다.**

모든 FA01HC 랩의 기본 리전을 `us-east-1`로 통일했기 때문에 대부분의 인프라 실습은 정책 리전 제한에 맞습니다. 다만 아래 보안 서비스 활성화 실습은 계속 막힙니다.

1. GuardDuty, Inspector, Macie, Security Hub 활성화 실습은 정책의 명시적 Deny 때문에 실패합니다.

## CSV 확인

비밀번호는 확인/출력하지 않았습니다.

- 계정 수: 21개
- 사용자명: `terraform-user-1`
- 비고: 첫 로그인 시 패스워드 변경 필요
- CSV는 콘솔 로그인용 정보입니다. Terraform CLI 실행에는 별도 access key 또는 CloudShell 기반 실행이 필요합니다.

정책상 `terraform-user-1`의 access key 생성은 명시 Deny 대상이 아닙니다. Deny는 `terraform-user-0` 수정/삭제/키 관리에만 걸려 있습니다.

## 정책 핵심

| Sid | 영향 |
| --- | --- |
| `AllowAllServices` | 기본적으로 모든 서비스와 리소스를 허용 |
| `DenyAllServicesOutsideUsEast1` | `aws:RequestedRegion != us-east-1`이면 모든 액션 Deny |
| `DenyCostlyServicesAndSubscriptions` | 예약 구매, Savings Plans, Shield 구독, GuardDuty/SecurityHub/Macie/Inspector 활성화 등 Deny |
| `DenyModifyOrDeleteTerraformUser0` | `terraform-user-0` 보호 |
| `DenyHighCostInstanceTypes` | metal, 12xlarge 이상, GPU/AI/HPC 계열 인스턴스 실행 Deny |

명시적 Deny는 추가 Allow 정책으로 우회할 수 없습니다.

## 바로 가능한 실습

아래 실습들은 현재 정책 기준으로 `us-east-1`에서 진행 가능성이 높습니다.

| Day | 단원 | 경로 | 메모 |
| --- | --- | --- | --- |
| 1 | AWS 서비스 살펴보기 | `terraform/fa01hc/day01-cloud-and-account-security/04-aws-services-overview` | data-only 확인 실습 |
| 1 | AWS 계정 구성, 계정 보호 및 사용자 접근 제어 | `terraform/fa01hc/day01-cloud-and-account-security/05-account-protection-and-access-control` | `terraform-user-0`을 건드리지 않음 |
| 1 | AWS IAM 기본 | `terraform/fa01hc/day01-cloud-and-account-security/06-iam-basics` | IAM 사용자/정책 실습 가능 |
| 2 | CloudTrail 이벤트를 활용한 유저 감사와 CloudWatch 경보 | `terraform/fa01hc/day02-account-and-compute-security/01-cloudtrail-user-audit-cloudwatch-alarm` | CloudTrail, S3, CloudWatch |
| 2 | IAM 액세스 분석기 | `terraform/fa01hc/day02-account-and-compute-security/02-iam-access-analyzer` | Access Analyzer 활성화 |
| 2 | EC2를 활용한 가상머신 구성과 활용 이해 / 공인 IP 이해 | `terraform/fa01hc/day02-account-and-compute-security/03-ec2-virtual-machine-and-public-ip` | 인스턴스 타입이 고비용 Deny 목록에 걸리지 않으면 가능 |
| 2 | 부트스트랩 / EBS 기본 기능 이해 | `terraform/fa01hc/day02-account-and-compute-security/04-bootstrap-and-ebs` | EC2, EBS |
| 2 | 배치 그룹 / 예약·스팟 인스턴스 비용 절감 | `terraform/fa01hc/day02-account-and-compute-security/05-placement-group-reserved-spot-instances` | Spot은 가능, Reserved 구매는 정책상 불가 |
| 2 | Lambda와 API Gateway 서버리스 컴퓨팅 | `terraform/fa01hc/day02-account-and-compute-security/06-lambda-api-gateway-serverless` | Lambda, API Gateway |
| 2 | ECS/EKS 컨테이너 컴퓨팅 | `terraform/fa01hc/day02-account-and-compute-security/07-ecs-eks-container-computing` | 현재 구성은 ECS Fargate 중심 |
| 3 | S3 정적 콘텐츠 서비스 | `terraform/fa01hc/day03-compute-and-network-security/01-s3-static-content-service` | S3 |
| 3 | VPC / Security Group / NACL | `terraform/fa01hc/day03-compute-and-network-security/02-vpc-security-group-nacl` | VPC, EC2, EBS |
| 3 | Bastion / NAT / Egress-only IGW | `terraform/fa01hc/day03-compute-and-network-security/03-bastion-nat-egress-only-gateway` | NAT Gateway 비용 주의 |
| 3 | VPC Endpoint / Routing | `terraform/fa01hc/day03-compute-and-network-security/04-vpc-endpoint-and-routing` | NAT Gateway, Interface Endpoint 비용 주의 |
| 3 | CloudFront / Route53 | `terraform/fa01hc/day03-compute-and-network-security/05-cloudfront-route53` | Global 서비스는 us-east-1 정책과 함께 사전 리허설 필요 |
| 3 | AWS WAF 웹 애플리케이션 보호 | `terraform/fa01hc/day03-compute-and-network-security/06-aws-waf-web-application-protection` | CloudFront용 WAF는 us-east-1 |
| 3 | VPC Peering | `terraform/fa01hc/day03-compute-and-network-security/07-vpc-peering` | VPC 간 연결 |
| 4 | ALB / Auto Scaling | `terraform/fa01hc/day04-network-and-storage-security/01-load-balancer-autoscaling-availability` | ALB, ASG, EC2 비용 주의 |
| 4 | VPN과 Direct Connect 이해 | `terraform/fa01hc/day04-network-and-storage-security/02-vpn-direct-connect` | 실제 apply 전 `customer_gateway_ip`를 실제 공인 IP로 교체 필요 |
| 4 | Aurora / RDS | `terraform/fa01hc/day04-network-and-storage-security/03-aurora-rds-relational-database` | 생성 시간/비용 주의 |
| 4 | DynamoDB | `terraform/fa01hc/day04-network-and-storage-security/04-dynamodb-key-value-database` | 가능 |
| 4 | ElastiCache | `terraform/fa01hc/day04-network-and-storage-security/05-elasticache-caching-server` | 비용 주의 |
| 4 | KMS / 저장소 암호화 | `terraform/fa01hc/day04-network-and-storage-security/06-kms-storage-encryption` | KMS, S3, EC2 |
| 5 | Secrets Manager | `terraform/fa01hc/day05-storage-and-security-services/01-secrets-manager-secret-management` | Secrets Manager, Lambda rotation |

## us-east-1 통일 완료 실습

아래 실습은 정책 검토 당시 다른 리전 값이 있었지만, 현재는 `aws_region = "us-east-1"`로 수정했습니다.

| Day | 단원 | 경로 | 상태 |
| --- | --- | --- | --- |
| 4 | S3 액세스 로그 기록 | `terraform/fa01hc/day04-network-and-storage-security/07-s3-access-logs` | `us-east-1` 수정 완료 |
| 5 | AWS Config 규정 준수 | `terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance` | `us-east-1` 수정 완료 |
| 5 | Inspector 취약성 관리 | `terraform/fa01hc/day05-storage-and-security-services/03-inspector-vulnerability-management` | `us-east-1` 수정 완료, 단 정책 Deny 별도 존재 |
| 5 | GuardDuty 악성코드 탐지 | `terraform/fa01hc/day05-storage-and-security-services/04-guardduty-threat-detection` | `us-east-1` 수정 완료, 단 정책 Deny 별도 존재 |
| 5 | Macie 민감 정보 탐지 | `terraform/fa01hc/day05-storage-and-security-services/05-macie-sensitive-data-discovery` | `us-east-1` 수정 완료, 단 정책 Deny 별도 존재 |
| 5 | Security Hub / Incident Manager | `terraform/fa01hc/day05-storage-and-security-services/06-securityhub-incident-manager` | `us-east-1` 수정 완료, 단 정책 Deny 별도 존재 |

## 정책상 불가능한 실습

아래 실습은 `DenyCostlyServicesAndSubscriptions`에 직접 걸립니다.
리전을 `us-east-1`로 바꿔도 명시적 Deny 때문에 apply가 실패합니다.

| Day | 단원 | 경로 | 막히는 액션 |
| --- | --- | --- | --- |
| 5 | Inspector 취약성 관리 | `terraform/fa01hc/day05-storage-and-security-services/03-inspector-vulnerability-management` | `inspector2:Enable` |
| 5 | GuardDuty 악성코드 탐지 | `terraform/fa01hc/day05-storage-and-security-services/04-guardduty-threat-detection` | `guardduty:CreateDetector`, `guardduty:UpdateDetector` |
| 5 | Macie 민감 정보 탐지 | `terraform/fa01hc/day05-storage-and-security-services/05-macie-sensitive-data-discovery` | `macie2:EnableMacie`, `macie2:UpdateMacieSession` |
| 5 | Security Hub / Incident Manager | `terraform/fa01hc/day05-storage-and-security-services/06-securityhub-incident-manager` | `securityhub:EnableSecurityHub`, `securityhub:UpdateSecurityHubConfiguration` |

## 계정 전제조건이 필요한 실습

| Day | 단원 | 경로 | 전제조건 |
| --- | --- | --- | --- |
| 1 | IAM Identity Center SSO 유저 관리 | `terraform/fa01hc/day01-cloud-and-account-security/07-iam-identity-center-sso` | 계정에 IAM Identity Center 인스턴스가 있어야 하며 `sso_instance_arn`, `identity_store_id` 값이 필요 |
| 4 | VPN과 Direct Connect 이해 | `terraform/fa01hc/day04-network-and-storage-security/02-vpn-direct-connect` | `customer_gateway_ip = "203.0.113.10"`은 문서용 IP이므로 실제 공인 IP로 교체 필요 |

## 권장 조치

1. Day 5 보안 서비스 활성화 실습은 별도 관리자 계정 또는 Deny 제거 버전 정책이 필요합니다.
2. Inspector, GuardDuty, Macie, Security Hub는 이 제한 정책에서는 콘솔 데모/샘플 화면/기존 활성화 계정 관찰 실습으로 대체합니다.
3. Terraform CLI 실행을 위해 각 `terraform-user-1` 사용자는 첫 로그인 후 access key를 만들거나 CloudShell에서 실습합니다.
4. 실제 apply는 반드시 `CONFIRM_APPLY_DESTROY=YES make lifecycle-apply-destroy LAB=<path>`로 실행합니다.

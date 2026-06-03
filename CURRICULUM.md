# FA01HC Curriculum Mapping

Authoritative course page:

- https://m.multicampus.com/course/crsDetail?corsCd=FA01HC

## Current Status

`terraform/fa01hc/` now mirrors the FA01HC course curriculum. The previous `gasbugs/mulcam-aws-infra-automation-terraform` repository was used as reusable source material while composing these labs.

## Target

The final structure mirrors the FA01HC course curriculum:

```text
terraform/
  fa01hc/
    day01-cloud-and-account-security/
    day02-account-and-compute-security/
    day03-compute-and-network-security/
    day04-network-and-storage-security/
    day05-storage-and-security-services/
```

Each unit directory is either a runnable Terraform root module or a clearly documented non-Terraform guide lab.

## Mapping Rules

- Use the FA01HC course page as the source of truth for chapter and unit order.
- Use the imported repository only as reusable source material.
- Keep `terraform.tfvars` files when they are part of the intended lab.
- Keep `terraform.tfvars.example` files when they help instructors or learners prepare variants.
- Treat `fa01hc-curriculum.json` as the final day/unit manifest.
- Keep `labs.json` only as imported source inventory.

## Day Mapping

| Day | Unit | Kind | Path |
| --- | --- | --- | --- |
| 1 | 클라우드 서비스 개념 | guide | `terraform/fa01hc/day01-cloud-and-account-security/01-cloud-service-concepts` |
| 1 | 클라우드 보안 이해 | guide | `terraform/fa01hc/day01-cloud-and-account-security/02-cloud-security-fundamentals` |
| 1 | AWS 환경에서 사고 대응 | guide | `terraform/fa01hc/day01-cloud-and-account-security/03-aws-incident-response-overview` |
| 1 | AWS 서비스 살펴보기 | terraform | `terraform/fa01hc/day01-cloud-and-account-security/04-aws-services-overview` |
| 1 | AWS 계정 구성, 계정 보호 및 사용자 접근 제어 | terraform | `terraform/fa01hc/day01-cloud-and-account-security/05-account-protection-and-access-control` |
| 1 | AWS IAM 기본 | terraform | `terraform/fa01hc/day01-cloud-and-account-security/06-iam-basics` |
| 1 | IAM Identity Center를 활용한 SSO 유저 관리 | terraform | `terraform/fa01hc/day01-cloud-and-account-security/07-iam-identity-center-sso` |
| 2 | CloudTrail 이벤트를 활용한 유저 감사와 CloudWatch 경보 | terraform | `terraform/fa01hc/day02-account-and-compute-security/01-cloudtrail-user-audit-cloudwatch-alarm` |
| 2 | IAM 액세스 분석기 | terraform | `terraform/fa01hc/day02-account-and-compute-security/02-iam-access-analyzer` |
| 2 | EC2를 활용한 가상머신 구성과 활용 이해 / 공인 IP 이해 | terraform | `terraform/fa01hc/day02-account-and-compute-security/03-ec2-virtual-machine-and-public-ip` |
| 2 | 부트스트랩 / EBS 기본 기능 이해 | terraform | `terraform/fa01hc/day02-account-and-compute-security/04-bootstrap-and-ebs` |
| 2 | 배치 그룹을 활용한 스케줄링 전략 이해 / 예약·스팟 인스턴스를 활용한 비용 절감 | terraform | `terraform/fa01hc/day02-account-and-compute-security/05-placement-group-reserved-spot-instances` |
| 2 | 람다와 API 게이트웨이를 활용한 서버리스 컴퓨팅 이해 | terraform | `terraform/fa01hc/day02-account-and-compute-security/06-lambda-api-gateway-serverless` |
| 2 | ECS/EKS를 활용한 컨테이너 컴퓨팅 이해 | terraform | `terraform/fa01hc/day02-account-and-compute-security/07-ecs-eks-container-computing` |
| 3 | S3를 활용한 저장소 구성과 웹 정적 컨텐츠 서비스 이해 | terraform | `terraform/fa01hc/day03-compute-and-network-security/01-s3-static-content-service` |
| 3 | VPC를 활용한 가상 네트워크 구성 이해 / 보안 그룹·NACLs를 활용한 보호 이해 | terraform | `terraform/fa01hc/day03-compute-and-network-security/02-vpc-security-group-nacl` |
| 3 | 베스쳔 호스트 / NAT 게이트웨이와 Egress-Only Internet Gateway | terraform | `terraform/fa01hc/day03-compute-and-network-security/03-bastion-nat-egress-only-gateway` |
| 3 | VPC 엔드포인트 / VPC 라우팅 | terraform | `terraform/fa01hc/day03-compute-and-network-security/04-vpc-endpoint-and-routing` |
| 3 | CloudFront와 Route53 이해 | terraform | `terraform/fa01hc/day03-compute-and-network-security/05-cloudfront-route53` |
| 3 | AWS WAF를 활용한 웹 애플리케이션 보호 | terraform | `terraform/fa01hc/day03-compute-and-network-security/06-aws-waf-web-application-protection` |
| 3 | VPC 피어링를 활용한 VPC 간 연결 | terraform | `terraform/fa01hc/day03-compute-and-network-security/07-vpc-peering` |
| 4 | 로드밸런서와 오토스케일링를 활용한 가상머신 가용성 구성 | terraform | `terraform/fa01hc/day04-network-and-storage-security/01-load-balancer-autoscaling-availability` |
| 4 | VPN과 다이렉트 커넥트 이해 | terraform | `terraform/fa01hc/day04-network-and-storage-security/02-vpn-direct-connect` |
| 4 | Aurora와 RDS를 활용한 관계형 데이터베이스 | terraform | `terraform/fa01hc/day04-network-and-storage-security/03-aurora-rds-relational-database` |
| 4 | DynamoDB를 활용한 Key-Value 데이터베이스 | terraform | `terraform/fa01hc/day04-network-and-storage-security/04-dynamodb-key-value-database` |
| 4 | ElastiCache를 활용한 캐싱 서버 | terraform | `terraform/fa01hc/day04-network-and-storage-security/05-elasticache-caching-server` |
| 4 | KMS 서비스를 활용한 키 구성과 저장소 암호화 | terraform | `terraform/fa01hc/day04-network-and-storage-security/06-kms-storage-encryption` |
| 4 | S3 액세스 로그 기록 | terraform | `terraform/fa01hc/day04-network-and-storage-security/07-s3-access-logs` |
| 5 | Secret Manager를 활용한 비밀 정보 관리 | terraform | `terraform/fa01hc/day05-storage-and-security-services/01-secrets-manager-secret-management` |
| 5 | AWS Config를 활용한 규정 준수 | terraform | `terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance` |
| 5 | Inspector를 활용한 취약성 관리 | terraform | `terraform/fa01hc/day05-storage-and-security-services/03-inspector-vulnerability-management` |
| 5 | GuardDuty를 활용한 악성코드 탐지 | terraform | `terraform/fa01hc/day05-storage-and-security-services/04-guardduty-threat-detection` |
| 5 | Macie를 활용한 민감 정보 탐지 | terraform | `terraform/fa01hc/day05-storage-and-security-services/05-macie-sensitive-data-discovery` |
| 5 | SecurityHub를 활용한 보안 상태 통합 보기, Incident Manager를 활용한 대응 계획 수립 | terraform | `terraform/fa01hc/day05-storage-and-security-services/06-securityhub-incident-manager` |

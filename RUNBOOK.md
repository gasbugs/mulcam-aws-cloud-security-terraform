# FA01HC Terraform Lab Runbook

이 문서는 FA01HC 강의 실습을 실제 AWS 계정에서 리허설할 때의 권장 순서입니다.

## 원칙

- 먼저 전체 루트의 `init`/`validate`를 통과시킨다.
- 그 다음 일차별로 `plan`을 확인한다.
- 실제 리소스 테스트는 단원 하나씩 실행한다.
- `apply`를 실행한 단원은 같은 세션에서 반드시 `destroy`까지 확인한다.
- 비용이 큰 리소스는 하루 단위 전체 적용 대신 단원 단위로 짧게 켰다가 내린다.

## 1. 전체 정적 검증

```bash
make check
```

검증 대상은 [terraform-roots.txt](terraform-roots.txt)에 있는 FA01HC Terraform 루트입니다.

## 2. 강의 순서 확인

```bash
make list
make roots
```

## 3. 단원별 plan 리허설

전체 루트의 비파괴 plan 가능 여부를 먼저 확인합니다.

```bash
make plan-check
```

그 다음 단원별로 상세 출력을 확인합니다.

```bash
make lifecycle-plan LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

`plan`은 리소스를 만들지 않지만 AWS API와 data source를 조회할 수 있습니다.

기본 AWS credential chain 대신 특정 AWS CLI profile을 쓰려면 아래처럼 실행합니다.

```bash
FA01HC_AWS_PROFILE=my-profile make plan-check
```

## 4. 단원별 apply 후 destroy 테스트

실제 리소스를 만드는 테스트는 아래처럼 확인 변수를 명시해야 실행됩니다.

```bash
CONFIRM_APPLY_DESTROY=YES make lifecycle-apply-destroy LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

스크립트는 `apply`가 실행된 뒤 성공/실패와 관계없이 `destroy`를 시도합니다. 이후 Terraform state에 관리 리소스가 남아 있으면 실패로 종료합니다.

## 5. 우선 리허설 순서

1. Day 1 계정/IAM 계열
2. Day 2 CloudTrail, Access Analyzer, EC2 기본
3. Day 3 VPC, S3, CloudFront/WAF 계열
4. Day 4 ALB/ASG, RDS/Aurora, DynamoDB, ElastiCache, KMS
5. Day 5 Secrets Manager, Config, Inspector, GuardDuty, Macie, Security Hub

## 비용 주의 단원

- NAT Gateway: `day03-compute-and-network-security/03-bastion-nat-egress-only-gateway`
- VPC Foundation NAT/Client VPN: `common/01-vpc-network-foundation`
- ALB/ASG: `day04-network-and-storage-security/01-load-balancer-autoscaling-availability`
- RDS/Aurora: `day04-network-and-storage-security/03-aurora-rds-relational-database`
- ElastiCache: `day04-network-and-storage-security/05-elasticache-caching-server`
- Macie, GuardDuty, Security Hub: `day05-storage-and-security-services/*`

## 테스트 후 삭제 확인

각 단원 테스트 후 다음을 확인합니다.

```bash
terraform -chdir=<LAB> state list
terraform -chdir=<LAB> plan -destroy
```

`state list`에 리소스가 남아 있거나 `plan -destroy`가 삭제 대상을 보여주면 `destroy`가 끝나지 않은 상태입니다.

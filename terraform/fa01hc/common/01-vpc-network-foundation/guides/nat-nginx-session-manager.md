# NAT Gateway 구성해서 nginx 설치하기

이 가이드는 Terraform이 만든 기본 VPC에서 수강생이 NAT Gateway와 private route를 직접 추가한 뒤, Session Manager로 private EC2에 접속해 nginx를 설치하는 실습입니다.

Terraform 기본 구성에는 NAT Gateway와 Session Manager IAM role이 없습니다. 이 가이드에서 필요한 리소스를 직접 만들고 마지막에 삭제합니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| 기본 준비 | VPC, public/private subnet, private EC2, SSH key |
| 직접 구성 | Elastic IP, NAT Gateway, private route, EC2 SSM IAM role/profile |
| 검증 | private EC2에서 `dnf install nginx` 성공 |
| 리전 | `us-east-1` |

## 1. 저장소 clone 및 기본 VPC 생성

로컬 PC 또는 WSL에 AWS CLI v2와 Session Manager plugin이 설치되어 있어야 합니다.

```bash
aws --version
session-manager-plugin
```

`session-manager-plugin` 명령이 없으면 먼저 설치합니다.

```bash
git clone https://github.com/gasbugs/mulcam-aws-cloud-security-terraform.git
cd mulcam-aws-cloud-security-terraform

REPO_DIR=$(pwd)
LAB_DIR=terraform/fa01hc/common/01-vpc-network-foundation

terraform -chdir="$LAB_DIR" init
terraform -chdir="$LAB_DIR" apply
cd "$LAB_DIR"
```

필요한 값을 변수로 저장합니다.

```bash
PROJECT_NAME=fa01hc-vpc-network-foundation
REGION=us-east-1

INSTANCE_ID=$(terraform output -raw private_instance_id)
VPC_ID=$(terraform output -raw vpc_id)

PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=public" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region "$REGION")

PRIVATE_ROUTE_TABLE_IDS=($(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=private" \
  --query "RouteTables[].RouteTableId" \
  --output text \
  --region "$REGION"))
```

## 2. NAT Gateway 생성

Elastic IP를 할당합니다.

```bash
ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query AllocationId \
  --output text \
  --region "$REGION")

echo "$ALLOCATION_ID"
```

public subnet에 NAT Gateway를 생성합니다.

```bash
NAT_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --allocation-id "$ALLOCATION_ID" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$PROJECT_NAME-nat},{Key=Course,Value=FA01HC},{Key=Unit,Value=vpc-network-foundation}]" \
  --query NatGateway.NatGatewayId \
  --output text \
  --region "$REGION")

aws ec2 wait nat-gateway-available \
  --nat-gateway-ids "$NAT_ID" \
  --region "$REGION"
```

private route table에 기본 경로를 추가합니다.

```bash
for ROUTE_TABLE_ID in "${PRIVATE_ROUTE_TABLE_IDS[@]}"; do
  aws ec2 create-route \
    --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id "$NAT_ID" \
    --region "$REGION"
done
```

## 3. Session Manager용 IAM role 연결

NAT 경로가 생겼으므로 private EC2는 public SSM endpoint로 outbound HTTPS 통신할 수 있습니다. 이제 EC2에 SSM 권한을 붙입니다.

```bash
ROLE_NAME="$PROJECT_NAME-ssm-role"
PROFILE_NAME="$PROJECT_NAME-ssm-instance-profile"

TRUST_POLICY_JSON='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY_JSON"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"

sleep 15

ASSOCIATION_ID=$(aws ec2 associate-iam-instance-profile \
  --instance-id "$INSTANCE_ID" \
  --iam-instance-profile "Name=$PROFILE_NAME" \
  --query IamInstanceProfileAssociation.AssociationId \
  --output text \
  --region "$REGION")
```

EC2가 새 instance profile과 NAT 경로를 확실히 인식하도록 한 번 재부팅합니다.

```bash
aws ec2 reboot-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

aws ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"
```

SSM online 상태를 확인합니다.

```bash
for i in {1..24}; do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query "InstanceInformationList[0].PingStatus" \
    --output text \
    --region "$REGION")

  echo "$STATUS"

  if [ "$STATUS" = "Online" ]; then
    break
  fi

  sleep 15
done
```

`Online`이 아니면 1분 뒤 다시 확인합니다.

`Online`으로 바뀐 직후에는 명령/세션 채널이 아직 준비 중일 수 있으므로 60초 정도 더 기다립니다.

```bash
sleep 60
```

## 4. Session Manager로 접속

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$REGION"
```

## 5. NAT Gateway outbound 테스트

EC2 내부에서 실행합니다.

```bash
curl -s https://checkip.amazonaws.com
```

출력되는 IP는 NAT Gateway의 Elastic IP입니다. private EC2가 NAT Gateway를 통해 인터넷으로 나간다는 뜻입니다.

## 6. nginx 설치 및 실행

EC2 내부에서 실행합니다.

```bash
sudo dnf clean all
sudo dnf install -y nginx
sudo systemctl enable --now nginx
systemctl status nginx --no-pager
curl -I http://127.0.0.1
exit
```

`HTTP/1.1 200 OK` 또는 `HTTP/1.1 403 Forbidden`이 보이면 nginx가 응답하는 상태입니다.

## 7. 정리

직접 만든 리소스를 먼저 삭제합니다.

```bash
aws ec2 disassociate-iam-instance-profile \
  --association-id "$ASSOCIATION_ID" \
  --region "$REGION"

sleep 30

for ROUTE_TABLE_ID in "${PRIVATE_ROUTE_TABLE_IDS[@]}"; do
  aws ec2 delete-route \
    --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --region "$REGION"
done

aws ec2 delete-nat-gateway \
  --nat-gateway-id "$NAT_ID" \
  --region "$REGION"

aws ec2 wait nat-gateway-deleted \
  --nat-gateway-ids "$NAT_ID" \
  --region "$REGION"

aws ec2 release-address \
  --allocation-id "$ALLOCATION_ID" \
  --region "$REGION"

aws iam remove-role-from-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"

aws iam delete-instance-profile \
  --instance-profile-name "$PROFILE_NAME"

aws iam detach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam delete-role \
  --role-name "$ROLE_NAME"
```

마지막으로 Terraform 리소스를 삭제합니다.

```bash
cd "$REPO_DIR"
terraform -chdir="$LAB_DIR" destroy
```

## 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| NAT Gateway 생성이 오래 걸림 | `aws ec2 wait nat-gateway-available` 완료까지 몇 분 걸릴 수 있습니다. |
| `create-route`가 실패함 | private route table에 이미 `0.0.0.0/0` 경로가 있는지 확인합니다. |
| Session Manager가 `Online`이 아님 | NAT route, EC2 IAM role, instance profile 연결 상태를 확인합니다. |
| `dnf install` 실패 | private route table의 기본 경로가 NAT Gateway인지 확인합니다. |
| Terraform destroy 실패 | NAT Gateway, route, IAM instance profile 같은 수동 리소스를 먼저 지웁니다. |

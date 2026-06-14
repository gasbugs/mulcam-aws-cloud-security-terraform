# Session Manager 구성해서 SSH 접속하기

이 가이드는 Terraform이 만든 기본 VPC와 private EC2에 Session Manager 접속 경로를 직접 추가하는 실습입니다. NAT Gateway 없이 SSM interface endpoint를 만들어 private EC2가 AWS Systems Manager와 통신하게 합니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| 기본 준비 | VPC, public/private subnet, private EC2, SSH key |
| 직접 구성 | EC2 IAM role/profile, SSM interface endpoints |
| 접속 방식 | Session Manager shell, SSH over Session Manager |
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
PRIVATE_INSTANCE_SG_ID=$(terraform output -raw private_instance_security_group_id)
KEY_FILE=$(terraform output -raw ssh_private_key_file)

chmod 400 "$KEY_FILE"
```

## 2. EC2용 IAM role과 instance profile 생성

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
```

instance profile에 role이 반영될 때까지 잠시 기다린 뒤 EC2에 연결합니다.

```bash
sleep 15

ASSOCIATION_ID=$(aws ec2 associate-iam-instance-profile \
  --instance-id "$INSTANCE_ID" \
  --iam-instance-profile "Name=$PROFILE_NAME" \
  --query IamInstanceProfileAssociation.AssociationId \
  --output text \
  --region "$REGION")

echo "$ASSOCIATION_ID"
```

## 3. SSM interface endpoint 생성

private EC2는 public IP와 NAT Gateway가 없으므로 SSM API에 연결할 VPC endpoint가 필요합니다.

```bash
ENDPOINT_SG_ID=$(aws ec2 create-security-group \
  --group-name "$PROJECT_NAME-ssm-endpoint-sg" \
  --description "SSM interface endpoint security group" \
  --vpc-id "$VPC_ID" \
  --query GroupId \
  --output text \
  --region "$REGION")

aws ec2 authorize-security-group-ingress \
  --group-id "$ENDPOINT_SG_ID" \
  --protocol tcp \
  --port 443 \
  --source-group "$PRIVATE_INSTANCE_SG_ID" \
  --region "$REGION"
```

private subnet ID를 조회합니다.

```bash
PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=private" \
  --query "Subnets[].SubnetId" \
  --output text \
  --region "$REGION"))

printf "%s\n" "${PRIVATE_SUBNET_IDS[@]}"
```

SSM endpoint 3개를 생성합니다.

```bash
for SERVICE in ssm ssmmessages ec2messages; do
  aws ec2 create-vpc-endpoint \
    --vpc-id "$VPC_ID" \
    --service-name "com.amazonaws.$REGION.$SERVICE" \
    --vpc-endpoint-type Interface \
    --subnet-ids "${PRIVATE_SUBNET_IDS[@]}" \
    --security-group-ids "$ENDPOINT_SG_ID" \
    --private-dns-enabled \
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=$PROJECT_NAME-$SERVICE-endpoint},{Key=Course,Value=FA01HC},{Key=Unit,Value=vpc-network-foundation}]" \
    --region "$REGION"
done
```

생성된 endpoint가 사용 가능해질 때까지 기다립니다.

```bash
ENDPOINT_IDS=($(aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Unit,Values=vpc-network-foundation" \
  --query "VpcEndpoints[].VpcEndpointId" \
  --output text \
  --region "$REGION"))

for i in {1..40}; do
  ENDPOINT_STATES=$(aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids "${ENDPOINT_IDS[@]}" \
    --query "VpcEndpoints[].State" \
    --output text \
    --region "$REGION")

  echo "$ENDPOINT_STATES"

  if [[ "$ENDPOINT_STATES" != *"pending"* ]]; then
    break
  fi

  sleep 15
done
```

EC2가 새 instance profile과 SSM endpoint DNS를 확실히 인식하도록 한 번 재부팅합니다.

```bash
aws ec2 reboot-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

aws ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"
```

## 4. Session Manager online 상태 확인

EC2의 SSM Agent가 endpoint와 IAM role을 인식하는 데 몇 분 걸릴 수 있습니다.

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

결과가 `Online`이면 접속할 수 있습니다. `None`이나 빈 값이면 1분 뒤 다시 확인합니다.

`Online`으로 바뀐 직후에는 명령/세션 채널이 아직 준비 중일 수 있으므로 60초 정도 더 기다립니다.

```bash
sleep 60
```

## 5. Session Manager shell 접속

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$REGION"
```

접속 후 확인합니다.

```bash
whoami
cat /etc/os-release
hostname -I
exit
```

## 6. SSH over Session Manager 접속

일반 Session Manager shell은 SSH key를 사용하지 않습니다. SSH over Session Manager는 SSH 프로토콜을 쓰므로 Terraform이 만든 key file을 사용합니다.

```bash
for i in {1..5}; do
  ssh -i "$KEY_FILE" "ec2-user@$INSTANCE_ID" \
    -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --region $REGION" && break

  sleep 30
done
```

`Online` 직후에는 Session Manager 채널 준비 타이밍 때문에 SSH가 한 번 실패할 수 있습니다. 이 경우 30초 정도 기다린 뒤 다시 시도합니다.

자주 접속하려면 `~/.ssh/config`에 추가합니다.

```sshconfig
Host i-* mi-*
    User ec2-user
    IdentityFile /absolute/path/to/generated/fa01hc-vpc-network-foundation-key.pem
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --region us-east-1"
```

## 7. 정리

먼저 직접 만든 SSM 리소스를 삭제합니다.

```bash
aws ec2 disassociate-iam-instance-profile \
  --association-id "$ASSOCIATION_ID" \
  --region "$REGION"

sleep 30

aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids "${ENDPOINT_IDS[@]}" \
  --region "$REGION"

for i in {1..20}; do
  aws ec2 delete-security-group \
    --group-id "$ENDPOINT_SG_ID" \
    --region "$REGION" && break

  sleep 15
done

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
| `TargetNotConnected` | IAM instance profile 연결, SSM endpoint 3개, endpoint SG의 443 허용을 확인합니다. |
| `SessionManagerPlugin is not found` | 로컬 PC에 Session Manager plugin을 설치합니다. |
| SSH over SSM 실패 | 일반 Session Manager shell이 먼저 열리는지 확인하고, key file 권한을 `chmod 400`으로 맞춥니다. |
| endpoint 삭제 실패 | 열려 있는 session을 종료하고 다시 삭제합니다. |

참고 문서:

- [Session Manager로 SSH 연결 사용](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)
- [Session Manager plugin 설치](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

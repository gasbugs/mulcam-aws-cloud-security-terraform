# Session Manager 구성해서 SSH 접속하기

이 문서는 `terraform/fa01hc/common/01-vpc-network-foundation`에서 생성한 private EC2에 접속하는 실습 가이드입니다.

기본 Session Manager shell은 SSH key를 사용하지 않습니다. IAM role, SSM Agent, SSM API 통신 경로로 접속합니다. SSH key는 Session Manager를 프록시로 사용하는 SSH 접속이나 Client VPN으로 private IP에 직접 SSH 접속할 때 사용합니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| 접속 대상 | Public IP가 없는 Amazon Linux 2023 private EC2 |
| 기본 접속 | AWS Systems Manager Session Manager shell |
| 추가 접속 | SSH over Session Manager |
| 리전 | `us-east-1` |

## 사전 준비

로컬 PC 또는 WSL에 다음 도구가 필요합니다.

| 도구 | 용도 |
| --- | --- |
| AWS CLI v2 | Session Manager 시작, EC2/SSM 상태 확인 |
| Session Manager plugin | `aws ssm start-session` 실행 |
| OpenSSH client | SSH over Session Manager 접속 |
| Terraform | 실습 VPC와 EC2 생성 |

AWS 자격 증명에는 최소한 다음 권한이 필요합니다.

```text
ssm:StartSession
ssm:DescribeInstanceInformation
ssm:TerminateSession
ec2:DescribeInstances
```

## 1. Terraform 구성 적용

프로젝트 루트에서 실행합니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation init
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation apply
```

이 실습의 기본 `terraform.tfvars`는 다음 흐름을 만듭니다.

| 구성 | 값 |
| --- | --- |
| `enable_nat_gateway` | `true` |
| `enable_ssm_instance` | `true` |
| `enable_ssm_vpc_endpoints` | `false` |
| EC2 AMI | Amazon Linux 2023 |

## 2. 출력값 확인

```bash
cd terraform/fa01hc/common/01-vpc-network-foundation

terraform output private_instance_id
terraform output private_instance_private_ip
terraform output ssh_private_key_file
terraform output session_manager_start_command
```

반복해서 사용할 값은 변수로 저장합니다.

```bash
INSTANCE_ID=$(terraform output -raw private_instance_id)
KEY_FILE=$(terraform output -raw ssh_private_key_file)
chmod 400 "$KEY_FILE"
```

Windows PowerShell에서는 다음처럼 확인합니다.

```powershell
$INSTANCE_ID = terraform output -raw private_instance_id
$KEY_FILE = terraform output -raw ssh_private_key_file
```

## 3. Session Manager 연결 상태 확인

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query "InstanceInformationList[0].PingStatus" \
  --output text \
  --region us-east-1
```

결과가 `Online`이면 접속할 수 있습니다.

## 4. Session Manager shell 접속

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region us-east-1
```

접속 후 EC2 내부에서 확인합니다.

```bash
whoami
cat /etc/os-release
hostname -I
exit
```

AWS 콘솔에서도 같은 작업을 할 수 있습니다.

1. AWS Console에서 `us-east-1` 리전을 선택합니다.
2. Systems Manager로 이동합니다.
3. Session Manager를 엽니다.
4. Start session을 선택합니다.
5. `fa01hc-vpc-network-foundation-private-ssm-instance` 인스턴스를 선택합니다.

## 5. SSH over Session Manager 접속

SSH over Session Manager는 SSH 프로토콜을 사용하므로 EC2 key pair가 필요합니다. 이 프로젝트는 Terraform TLS provider로 `generated/fa01hc-vpc-network-foundation-key.pem` 파일을 생성합니다.

### WSL 또는 Linux/macOS

한 번만 접속하려면 다음 명령을 사용합니다.

```bash
ssh -i "$KEY_FILE" "ec2-user@$INSTANCE_ID" \
  -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --region us-east-1"
```

자주 접속하려면 `~/.ssh/config`에 추가합니다.

```sshconfig
Host i-* mi-*
    User ec2-user
    IdentityFile /absolute/path/to/generated/fa01hc-vpc-network-foundation-key.pem
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --region us-east-1"
```

이후에는 인스턴스 ID로 접속합니다.

```bash
ssh "$INSTANCE_ID"
```

### Windows PowerShell

`%USERPROFILE%\.ssh\config`에 추가합니다.

```sshconfig
Host i-* mi-*
    User ec2-user
    IdentityFile C:/path/to/generated/fa01hc-vpc-network-foundation-key.pem
    ProxyCommand powershell.exe -NoProfile -Command "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --region us-east-1"
```

이후 PowerShell에서 접속합니다.

```powershell
ssh $INSTANCE_ID
```

## 6. 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| `TargetNotConnected` | EC2 생성 직후라면 1분 정도 기다린 뒤 다시 시도합니다. NAT Gateway 또는 SSM VPC endpoint 경로도 확인합니다. |
| `SessionManagerPlugin is not found` | AWS CLI용 Session Manager plugin을 설치합니다. |
| `AccessDeniedException` | 사용자 또는 role에 `ssm:StartSession` 권한이 있는지 확인합니다. |
| SSH에서 `Permission denied` | `KEY_FILE` 경로와 권한을 확인합니다. WSL/Linux는 `chmod 400`이 필요합니다. |
| SSH over SSM이 멈춤 | 일반 Session Manager shell이 먼저 열리는지 확인한 뒤 `AWS-StartSSHSession` 문서 이름을 다시 확인합니다. |

## 7. 정리

실습이 끝나면 Terraform으로 리소스를 삭제합니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation destroy
```

참고 문서:

- [AWS Systems Manager Session Manager로 SSH 연결 사용](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)
- [Session Manager plugin 설치](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

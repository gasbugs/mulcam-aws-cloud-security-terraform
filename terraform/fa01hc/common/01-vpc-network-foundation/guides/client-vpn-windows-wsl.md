# VPN 구성해서 접속하기

이 가이드는 Terraform이 만든 기본 VPC와 private EC2를 대상으로 AWS Client VPN endpoint를 수강생이 직접 구성하고, Windows 또는 WSL 환경에서 private EC2에 SSH로 접속하는 실습입니다.

Terraform 기본 구성에는 Client VPN endpoint가 없습니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| 기본 준비 | VPC, public/private subnet, private EC2, SSH key |
| 직접 구성 | ACM certificate, Client VPN endpoint, subnet association, authorization rule |
| VPN 방식 | AWS Client VPN mutual certificate authentication |
| Client CIDR | `172.16.0.0/22` |
| 리전 | `us-east-1` |

## 1. 저장소 clone 및 기본 VPC 생성

로컬 PC 또는 WSL에 AWS CLI v2, Terraform, OpenSSH client가 준비되어 있어야 합니다. 인증서 생성은 WSL 기준으로 진행하고, VPN 연결은 Windows의 AWS VPN Client 또는 OpenVPN client에서 진행합니다.

```bash
aws --version
aws sts get-caller-identity
terraform version
ssh -V
```

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
# terraform.tfvars에서 project_name을 변경했다면 아래 값도 같은 값으로 바꿉니다.
PROJECT_NAME=fa01hc-vpc-network-foundation
REGION=us-east-1
export AWS_PAGER=""

VPC_ID=$(terraform output -raw vpc_id)
VPC_CIDR=$(terraform output -raw vpc_cidr_block)
CLIENT_CIDR=$(terraform output -raw client_vpn_client_cidr_block)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
KEY_FILE=$(terraform output -raw ssh_private_key_file)

PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=private" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region "$REGION")

chmod 400 "$KEY_FILE"
```

## 2. 실습용 인증서 생성

WSL에서 EasyRSA를 사용합니다. `EASYRSA_BATCH=1`을 사용해 실습 중 대화형 입력을 줄입니다.

```bash
sudo apt update
sudo apt install -y easy-rsa
make-cadir ~/fa01hc-client-vpn-ca
cd ~/fa01hc-client-vpn-ca

export EASYRSA_BATCH=1
export EASYRSA_REQ_CN=fa01hc-client-vpn-ca

./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full student1.domain.tld nopass
```

## 3. 서버 인증서를 ACM에 등록

```bash
cd ~/fa01hc-client-vpn-ca

SERVER_CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://pki/issued/server.crt \
  --private-key fileb://pki/private/server.key \
  --certificate-chain fileb://pki/ca.crt \
  --region "$REGION" \
  --query CertificateArn \
  --output text)

echo "$SERVER_CERT_ARN"
```

server certificate와 client certificate가 같은 CA에서 발급되었으므로, 같은 ACM certificate ARN을 client root certificate chain으로 사용할 수 있습니다.

## 4. Client VPN endpoint security group 생성

Client VPN endpoint에 연결할 security group을 만듭니다. 기본 outbound rule은 전체 outbound 허용입니다.

```bash
CVPN_SG_ID=$(aws ec2 create-security-group \
  --group-name "$PROJECT_NAME-client-vpn-endpoint-sg" \
  --description "Client VPN endpoint security group" \
  --vpc-id "$VPC_ID" \
  --query GroupId \
  --output text \
  --region "$REGION")

echo "$CVPN_SG_ID"
```

private EC2 security group은 Terraform에서 이미 `172.16.0.0/22` 대역의 ICMP와 SSH를 허용합니다.

## 5. Client VPN endpoint 생성

Client VPN endpoint도 생성 시간 동안 비용이 발생합니다. 접속 테스트가 끝나면 정리 절차를 반드시 완료합니다.

```bash
AUTH_OPTIONS="[{\"Type\":\"certificate-authentication\",\"MutualAuthentication\":{\"ClientRootCertificateChainArn\":\"$SERVER_CERT_ARN\"}}]"

CVPN_ENDPOINT_ID=$(aws ec2 create-client-vpn-endpoint \
  --client-cidr-block "$CLIENT_CIDR" \
  --server-certificate-arn "$SERVER_CERT_ARN" \
  --authentication-options "$AUTH_OPTIONS" \
  --connection-log-options Enabled=false \
  --split-tunnel \
  --transport-protocol udp \
  --security-group-ids "$CVPN_SG_ID" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=client-vpn-endpoint,Tags=[{Key=Name,Value=$PROJECT_NAME-client-vpn},{Key=Course,Value=FA01HC},{Key=Unit,Value=vpc-network-foundation}]" \
  --query ClientVpnEndpointId \
  --output text \
  --region "$REGION")

echo "$CVPN_ENDPOINT_ID"
```

private subnet에 target network association을 만듭니다.

```bash
ASSOCIATION_ID=$(aws ec2 associate-client-vpn-target-network \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --query AssociationId \
  --output text \
  --region "$REGION")

echo "$ASSOCIATION_ID"
```

association이 완료될 때까지 기다립니다. 몇 분 걸릴 수 있습니다.

```bash
for i in {1..40}; do
  ASSOC_STATUS=$(aws ec2 describe-client-vpn-target-networks \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --association-ids "$ASSOCIATION_ID" \
    --query "ClientVpnTargetNetworks[0].Status.Code" \
    --output text \
    --region "$REGION")

  echo "$ASSOC_STATUS"

  if [ "$ASSOC_STATUS" = "associated" ]; then
    break
  fi

  sleep 15
done
```

```bash
if [ "$ASSOC_STATUS" != "associated" ]; then
  echo "Client VPN target network association 상태를 확인하세요: $ASSOC_STATUS"
  exit 1
fi
```

VPC CIDR 접근을 허용합니다.

```bash
aws ec2 authorize-client-vpn-ingress \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --target-network-cidr "$VPC_CIDR" \
  --authorize-all-groups \
  --region "$REGION"
```

콘솔에서 **VPC > Client VPN endpoints**로 이동해 endpoint와 target network association이 available/associated 상태인지, authorization rule이 active 상태인지 확인합니다.

## 6. Client VPN 설정 파일 생성

```bash
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --region "$REGION" \
  --query ClientConfiguration \
  --output text > client-config.ovpn
```

client certificate와 private key를 `.ovpn` 파일에 추가합니다.

```bash
{
  echo ""
  echo "<cert>"
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' ~/fa01hc-client-vpn-ca/pki/issued/student1.domain.tld.crt
  echo "</cert>"
  echo "<key>"
  cat ~/fa01hc-client-vpn-ca/pki/private/student1.domain.tld.key
  echo "</key>"
} >> client-config.ovpn
```

WSL 파일은 Windows Explorer에서 `\\wsl$` 경로로 접근할 수 있습니다.

## 7. Windows에서 VPN 연결

1. AWS VPN Client 또는 OpenVPN client를 설치합니다.
2. `client-config.ovpn` 파일을 import합니다.
3. 프로필을 선택하고 Connect를 누릅니다.
4. 연결 상태가 Connected인지 확인합니다.

PowerShell에서 private EC2가 보이는지 확인합니다.

```powershell
ping <PRIVATE_IP>
```

SSH로 접속합니다.

```powershell
ssh -i C:\path\to\fa01hc-vpc-network-foundation-key.pem ec2-user@<PRIVATE_IP>
```

`<PRIVATE_IP>`는 `terraform output -raw private_instance_private_ip` 결과로 바꿔 입력합니다. SSH key가 WSL 안에 있다면 다음 단계처럼 WSL에서 SSH 접속하는 방식을 권장합니다.

## 8. WSL에서 접속 확인

Windows에서 VPN을 연결한 뒤 WSL에서 실행합니다.

```bash
ping -c 4 "$PRIVATE_IP"
ssh -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"
```

WSL2에서 Windows VPN 경로가 바로 반영되지 않으면 Windows PowerShell에서 먼저 ping을 테스트합니다. PowerShell에서는 되는데 WSL에서 안 되면 아래 명령으로 WSL을 재시작한 뒤 다시 확인합니다.

```powershell
wsl --shutdown
```

## 9. 정리

Windows VPN client에서 연결을 끊은 뒤 직접 만든 리소스를 삭제합니다.

```bash
aws ec2 disassociate-client-vpn-target-network \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --association-id "$ASSOCIATION_ID" \
  --region "$REGION"

sleep 60

aws ec2 revoke-client-vpn-ingress \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --target-network-cidr "$VPC_CIDR" \
  --revoke-all-groups \
  --region "$REGION"

aws ec2 delete-client-vpn-endpoint \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --region "$REGION"

sleep 60

aws ec2 delete-security-group \
  --group-id "$CVPN_SG_ID" \
  --region "$REGION"

aws acm delete-certificate \
  --certificate-arn "$SERVER_CERT_ARN" \
  --region "$REGION"
```

마지막으로 Terraform 리소스를 삭제합니다.

```bash
cd "$REPO_DIR"
terraform -chdir="$LAB_DIR" destroy
```

## 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| VPN endpoint가 오래 걸림 | endpoint와 target network association 상태가 available이 될 때까지 기다립니다. |
| VPN은 연결됐지만 ping 실패 | authorization rule, Client VPN endpoint SG, private EC2 SG의 Client CIDR 허용을 확인합니다. |
| SSH 실패 | private key 경로, `ec2-user`, private EC2 SG의 22번 허용을 확인합니다. |
| WSL에서만 접속 실패 | Windows PowerShell에서 먼저 테스트하고, 필요하면 `wsl --shutdown` 후 WSL을 다시 엽니다. |
| 리소스 삭제 실패 | VPN client 연결을 끊고 association 삭제가 끝난 뒤 endpoint와 SG를 삭제합니다. |

참고 문서:

- [AWS Client VPN mutual authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/mutual.html)
- [AWS Client VPN client configuration export](https://docs.aws.amazon.com/cli/latest/reference/ec2/export-client-vpn-client-configuration.html)

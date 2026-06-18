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

로컬 PC 또는 WSL에 AWS CLI v2, Terraform, OpenSSH client가 준비되어 있어야 합니다. 인증서 생성은 WSL 기준으로 진행합니다. VPN 연결은 Windows의 AWS VPN Client를 사용하거나, Windows 라우팅에 영향을 주지 않도록 WSL 안에서 OpenVPN을 직접 실행할 수 있습니다.

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

cd "$LAB_DIR"
terraform init
terraform apply
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
KEY_FILE_RAW=$(terraform output -raw ssh_private_key_file)

case "$KEY_FILE_RAW" in
  /*) KEY_FILE="$KEY_FILE_RAW" ;;
  *) KEY_FILE="$(pwd)/$KEY_FILE_RAW" ;;
esac

PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=private" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region "$REGION")

chmod 400 "$KEY_FILE"
```

새 터미널을 열어도 값을 다시 불러올 수 있도록 환경변수 파일을 저장합니다.

```bash
cat > /tmp/fa01hc-vpc-network-foundation.env <<EOF
export REPO_DIR="$REPO_DIR"
export LAB_DIR="$LAB_DIR"
export PROJECT_NAME="$PROJECT_NAME"
export REGION="$REGION"
export VPC_ID="$VPC_ID"
export VPC_CIDR="$VPC_CIDR"
export CLIENT_CIDR="$CLIENT_CIDR"
export PRIVATE_IP="$PRIVATE_IP"
export KEY_FILE="$KEY_FILE"
export PRIVATE_SUBNET_ID="$PRIVATE_SUBNET_ID"
export AWS_PAGER=""
EOF

source /tmp/fa01hc-vpc-network-foundation.env

printf 'PRIVATE_IP=%s\nKEY_FILE=%s\n' "$PRIVATE_IP" "$KEY_FILE"
```

## 2. 실습용 인증서 생성

WSL에서 EasyRSA를 사용합니다. `EASYRSA_BATCH=1`을 사용해 실습 중 대화형 입력을 줄입니다.

```bash
sudo apt update
sudo apt install -y easy-rsa
make-cadir ~/fa01hc-client-vpn-ca
cd ~/fa01hc-client-vpn-ca

export EASYRSA_BATCH=1

./easyrsa init-pki

export EASYRSA_REQ_CN=fa01hc-client-vpn-ca
./easyrsa build-ca nopass

unset EASYRSA_REQ_CN

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

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export SERVER_CERT_ARN="$SERVER_CERT_ARN"
EOF
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

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export CVPN_SG_ID="$CVPN_SG_ID"
EOF
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

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export CVPN_ENDPOINT_ID="$CVPN_ENDPOINT_ID"
EOF
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

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export ASSOCIATION_ID="$ASSOCIATION_ID"
EOF
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

authorization rule이 `active` 상태가 될 때까지 기다립니다.

```bash
for i in {1..40}; do
  AUTH_STATUS=$(aws ec2 describe-client-vpn-authorization-rules \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --query "AuthorizationRules[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
    --output text \
    --region "$REGION")

  echo "$AUTH_STATUS"

  if [ "$AUTH_STATUS" = "active" ]; then
    break
  fi

  sleep 15
done

if [ "$AUTH_STATUS" != "active" ]; then
  echo "Client VPN authorization rule 상태를 확인하세요: $AUTH_STATUS"
  exit 1
fi
```

Client VPN route table에 VPC CIDR route가 `active`인지 확인합니다. Target network association을 만들면 VPC local route가 자동으로 추가되어야 하지만, 실습 중 상태 확인을 위해 명시적으로 확인합니다.

```bash
ROUTE_STATUS=$(aws ec2 describe-client-vpn-routes \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --query "Routes[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
  --output text \
  --region "$REGION")

echo "$ROUTE_STATUS"
```

`None`이 나오면 VPC CIDR route를 직접 추가합니다.

```bash
if [ "$ROUTE_STATUS" = "None" ]; then
  aws ec2 create-client-vpn-route \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --destination-cidr-block "$VPC_CIDR" \
    --target-vpc-subnet-id "$PRIVATE_SUBNET_ID" \
    --region "$REGION"
fi
```

route가 `active` 상태가 될 때까지 기다립니다.

```bash
for i in {1..40}; do
  ROUTE_STATUS=$(aws ec2 describe-client-vpn-routes \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --query "Routes[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
    --output text \
    --region "$REGION")

  echo "$ROUTE_STATUS"

  if [ "$ROUTE_STATUS" = "active" ]; then
    break
  fi

  sleep 15
done

if [ "$ROUTE_STATUS" != "active" ]; then
  echo "Client VPN route 상태를 확인하세요: $ROUTE_STATUS"
  exit 1
fi
```

콘솔에서 확인한다면 **VPC > Client VPN endpoints**로 이동해 endpoint와 target network association이 available/associated 상태인지, authorization rule과 route가 active 상태인지 확인합니다.

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

이미 VPN을 연결한 상태에서 authorization rule이나 route를 추가했다면 먼저 연결을 끊고 다시 연결합니다. Split tunnel Client VPN은 연결 시점의 endpoint route table을 클라이언트 route table에 내려줍니다.

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

Windows에서 VPN 연결 후 기존 외부 인터넷 접속이 끊기면 VPN이 기본 경로를 가져간 상태입니다. 이 가이드의 endpoint는 `--split-tunnel`로 생성하므로, 아래 명령이 `True`인지 먼저 확인합니다.

```bash
aws ec2 describe-client-vpn-endpoints \
  --client-vpn-endpoint-ids "$CVPN_ENDPOINT_ID" \
  --query "ClientVpnEndpoints[0].SplitTunnel" \
  --output text \
  --region "$REGION"
```

`False`가 나오면 split tunnel을 켠 뒤 설정 파일을 다시 export하고 VPN client에 다시 import합니다.

```bash
aws ec2 modify-client-vpn-endpoint \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --split-tunnel \
  --region "$REGION"
```

## 8. WSL에서 OpenVPN으로 직접 연결

Windows VPN Client 대신 WSL 안에서 OpenVPN을 실행하면 VPN 경로가 WSL 내부에만 적용됩니다. 이 방식은 Windows의 기존 외부 인터넷 통신을 건드리지 않고, WSL 터미널에서만 private EC2로 접속할 때 유용합니다.

이미 WSL OpenVPN을 실행 중인 상태에서 authorization rule이나 route를 추가했다면 `Ctrl+C`로 끊은 뒤 다시 실행합니다. Split tunnel route는 VPN 연결 시점에 적용됩니다.

새 WSL 터미널을 열었다면 먼저 실습 변수를 다시 불러옵니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env

printf 'PRIVATE_IP=%s\nKEY_FILE=%s\n' "$PRIVATE_IP" "$KEY_FILE"
```

WSL에서 OpenVPN을 설치합니다.

```bash
sudo apt update
sudo apt install -y openvpn iputils-ping openssh-client
```

TUN 장치가 있는지 확인합니다.

```bash
ls -l /dev/net/tun
```

`/dev/net/tun`이 없다고 나오면 아래 명령을 실행한 뒤 다시 확인합니다.

```bash
sudo modprobe tun 2>/dev/null || true
ls -l /dev/net/tun
```

OpenVPN을 foreground로 실행합니다. 이 터미널은 VPN 연결을 유지하는 동안 닫지 않습니다.

```bash
sudo openvpn --config client-config.ovpn
```

다른 WSL 터미널을 열어 VPN 인터페이스와 라우팅을 확인합니다.

```bash
ip addr show tun0
ip route
ip route get "$PRIVATE_IP"
```

`ip route get "$PRIVATE_IP"` 결과가 `tun0`를 사용해야 합니다. 기본 인터넷 경로는 계속 `eth0`를 사용해야 합니다.

```bash
ip route | grep default
```

private EC2로 ping과 SSH를 테스트합니다.

```bash
ping -c 4 "$PRIVATE_IP"
ssh -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"
```

VPN 연결을 끊으려면 OpenVPN을 실행 중인 터미널에서 `Ctrl+C`를 누릅니다.

## 9. Windows VPN 연결 후 WSL에서 접속 확인

Windows에서 VPN을 연결한 뒤 WSL에서 실행합니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env

printf 'PRIVATE_IP=%s\nKEY_FILE=%s\n' "$PRIVATE_IP" "$KEY_FILE"
```

```bash
ping -c 4 "$PRIVATE_IP"
ssh -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"
```

WSL2에서 Windows VPN 경로가 바로 반영되지 않으면 Windows PowerShell에서 먼저 ping을 테스트합니다. PowerShell에서는 되는데 WSL에서 안 되면 아래 명령으로 WSL을 재시작한 뒤 다시 확인합니다.

```powershell
wsl --shutdown
```

## 10. 정리

Windows VPN client 또는 WSL OpenVPN 연결을 끊은 뒤 직접 만든 리소스를 삭제합니다.

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
cd "$REPO_DIR/$LAB_DIR"
terraform destroy
```

## 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| VPN endpoint가 오래 걸림 | endpoint와 target network association 상태가 available이 될 때까지 기다립니다. |
| VPN은 연결됐지만 ping 실패 | authorization rule, Client VPN endpoint SG, private EC2 SG의 Client CIDR 허용을 확인합니다. |
| SSH 실패 | private key 경로, `ec2-user`, private EC2 SG의 22번 허용을 확인합니다. |
| WSL에서만 접속 실패 | Windows PowerShell에서 먼저 테스트하고, 필요하면 `wsl --shutdown` 후 WSL을 다시 엽니다. |
| WSL OpenVPN에서 접속 실패 | `ip addr show tun0`, `ip route get "$PRIVATE_IP"`로 VPN 경로가 `tun0`인지 확인합니다. |
| Windows VPN 연결 후 외부 인터넷이 끊김 | Client VPN endpoint의 split tunnel이 `True`인지 확인하고, 설정 파일을 다시 export/import합니다. |
| ping 실패가 계속됨 | Client VPN route table에 VPC CIDR route가 있는지 확인하고, 없으면 `create-client-vpn-route`로 추가합니다. |
| 특정 PC에서만 VPN 경로가 이상함 | 로컬 LAN, WSL, Docker 대역이 Client CIDR `172.16.0.0/22`와 겹치지 않는지 확인합니다. 겹치면 `terraform.tfvars`의 `client_vpn_client_cidr_block`을 다른 `/22` 대역으로 바꾼 뒤 VPC foundation부터 다시 생성합니다. |
| 리소스 삭제 실패 | VPN client 연결을 끊고 association 삭제가 끝난 뒤 endpoint와 SG를 삭제합니다. |

Client VPN route table 확인 명령입니다.

```bash
aws ec2 describe-client-vpn-routes \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --query "Routes[].{Destination:DestinationCidr,TargetSubnet:TargetSubnet,Type:Type,Status:Status.Code}" \
  --output table \
  --region "$REGION"
```

VPC CIDR route가 없다면 명시적으로 추가합니다.

```bash
aws ec2 create-client-vpn-route \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --destination-cidr-block "$VPC_CIDR" \
  --target-vpc-subnet-id "$PRIVATE_SUBNET_ID" \
  --region "$REGION"
```

참고 문서:

- [AWS Client VPN mutual authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/mutual.html)
- [AWS Client VPN client configuration export](https://docs.aws.amazon.com/cli/latest/reference/ec2/export-client-vpn-client-configuration.html)

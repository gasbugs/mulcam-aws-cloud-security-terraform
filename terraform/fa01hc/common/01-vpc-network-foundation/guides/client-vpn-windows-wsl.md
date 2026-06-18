# VPN 구성해서 접속하기

이 가이드는 Terraform이 만든 기본 VPC와 private EC2를 대상으로 AWS Client VPN endpoint를 직접 구성하고, WSL 환경에서 OpenVPN으로 private EC2에 SSH 접속하는 실습입니다.

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

WSL에 AWS CLI v2, Terraform, OpenSSH client가 준비되어 있어야 합니다. 아래 블록은 도구 확인, Terraform apply, 이후 단계에서 재사용할 환경변수 저장까지 한 번에 수행합니다.

```bash
# 현재 터미널에서 필요한 도구와 AWS 인증이 준비됐는지 먼저 확인합니다.
aws --version
aws sts get-caller-identity
terraform version
ssh -V

# 실습 저장소를 받고, VPC foundation Terraform 디렉터리로 이동합니다.
git clone https://github.com/gasbugs/mulcam-aws-cloud-security-terraform.git
cd mulcam-aws-cloud-security-terraform

REPO_DIR=$(pwd)
LAB_DIR=terraform/fa01hc/common/01-vpc-network-foundation

cd "$LAB_DIR"
terraform init

# VPC, public/private subnet, private EC2, SSH key를 생성합니다.
# -auto-approve를 사용하므로 Terraform 승인 질문 없이 바로 생성됩니다.
terraform apply -auto-approve

# 아래 변수들은 이후 AWS CLI/OpenVPN/SSH 단계에서 계속 재사용됩니다.
PROJECT_NAME=fa01hc-vpc-network-foundation
REGION=us-east-1
export AWS_PAGER=""

# Terraform output에서 방금 만든 VPC와 private EC2 정보를 가져옵니다.
VPC_ID=$(terraform output -raw vpc_id)
VPC_CIDR=$(terraform output -raw vpc_cidr_block)
CLIENT_CIDR=$(terraform output -raw client_vpn_client_cidr_block)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
PRIVATE_INSTANCE_SG_ID=$(terraform output -raw private_instance_security_group_id)
KEY_FILE_RAW=$(terraform output -raw ssh_private_key_file)

# SSH key 경로가 상대경로로 나오면 현재 Terraform 디렉터리 기준의 절대경로로 바꿉니다.
case "$KEY_FILE_RAW" in
  /*) KEY_FILE="$KEY_FILE_RAW" ;;
  *) KEY_FILE="$(pwd)/$KEY_FILE_RAW" ;;
esac

# Client VPN endpoint를 연결할 private subnet 하나를 선택합니다.
PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Tier,Values=private" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region "$REGION")

chmod 400 "$KEY_FILE"

# 새 WSL 터미널에서도 같은 값을 쓸 수 있도록 env 파일로 저장합니다.
# 이후 단계에서 source /tmp/fa01hc-vpc-network-foundation.env 로 다시 불러옵니다.
cat > /tmp/fa01hc-vpc-network-foundation.env <<EOF
export REPO_DIR="$REPO_DIR"
export LAB_DIR="$LAB_DIR"
export PROJECT_NAME="$PROJECT_NAME"
export REGION="$REGION"
export VPC_ID="$VPC_ID"
export VPC_CIDR="$VPC_CIDR"
export CLIENT_CIDR="$CLIENT_CIDR"
export PRIVATE_IP="$PRIVATE_IP"
export PRIVATE_INSTANCE_SG_ID="$PRIVATE_INSTANCE_SG_ID"
export KEY_FILE="$KEY_FILE"
export PRIVATE_SUBNET_ID="$PRIVATE_SUBNET_ID"
export AWS_PAGER=""
EOF

source /tmp/fa01hc-vpc-network-foundation.env

printf 'VPC_ID=%s\nPRIVATE_IP=%s\nKEY_FILE=%s\nPRIVATE_SUBNET_ID=%s\n' \
  "$VPC_ID" "$PRIVATE_IP" "$KEY_FILE" "$PRIVATE_SUBNET_ID"
```

새 WSL 터미널을 열면 shell 변수는 사라집니다. 이후 단계의 새 터미널 코드 블록은 `/tmp/fa01hc-vpc-network-foundation.env`를 다시 불러오도록 구성되어 있습니다.

## 2. 실습용 인증서 생성

EasyRSA로 Client VPN mutual authentication에 사용할 CA, server certificate, client certificate를 생성합니다. `EASYRSA_BATCH=1`을 사용해 대화형 입력을 줄입니다.

```bash
# EasyRSA를 설치하고 실습용 CA 디렉터리를 만듭니다.
sudo apt update
sudo apt install -y easy-rsa

make-cadir ~/fa01hc-client-vpn-ca
cd ~/fa01hc-client-vpn-ca

# EASYRSA_BATCH=1은 확인 질문을 줄여 복붙 실행이 멈추지 않게 합니다.
export EASYRSA_BATCH=1

# CA를 초기화하고, Client VPN server/client 인증서를 발급합니다.
./easyrsa init-pki

export EASYRSA_REQ_CN=fa01hc-client-vpn-ca
./easyrsa build-ca nopass

unset EASYRSA_REQ_CN

./easyrsa build-server-full server nopass
./easyrsa build-client-full student1.domain.tld nopass

# 필요한 인증서와 private key가 생성됐는지 확인합니다.
ls -l \
  pki/ca.crt \
  pki/issued/server.crt \
  pki/private/server.key \
  pki/issued/student1.domain.tld.crt \
  pki/private/student1.domain.tld.key
```

## 3. 서버 인증서를 ACM에 등록

서버 인증서를 ACM에 등록합니다. 이 실습에서는 server certificate와 client certificate가 같은 CA에서 발급되었으므로, 같은 ACM certificate ARN을 client root certificate chain으로 사용합니다.

```bash
# 앞 단계에서 저장한 REGION 같은 값을 다시 불러옵니다.
source /tmp/fa01hc-vpc-network-foundation.env
cd ~/fa01hc-client-vpn-ca

# AWS Client VPN endpoint가 사용할 server certificate를 ACM에 import합니다.
SERVER_CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://pki/issued/server.crt \
  --private-key fileb://pki/private/server.key \
  --certificate-chain fileb://pki/ca.crt \
  --region "$REGION" \
  --query CertificateArn \
  --output text)

# 뒤 단계에서 다시 쓸 수 있도록 ACM certificate ARN을 env 파일에 추가합니다.
cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export SERVER_CERT_ARN="$SERVER_CERT_ARN"
EOF

printf 'SERVER_CERT_ARN=%s\n' "$SERVER_CERT_ARN"
```

## 4. Client VPN endpoint security group 생성

Client VPN endpoint에 연결할 security group을 만들고, private EC2 security group에 endpoint security group source 허용을 추가합니다. Client VPN route type이 `Nat`로 보이는 환경에서는 EC2가 Client VPN endpoint security group을 source로 볼 수 있습니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env

# Client VPN endpoint에 붙일 security group을 생성합니다.
# 이 SG는 VPN endpoint 쪽 네트워크 인터페이스에 적용됩니다.
CVPN_SG_ID=$(aws ec2 create-security-group \
  --group-name "$PROJECT_NAME-client-vpn-endpoint-sg" \
  --description "Client VPN endpoint security group" \
  --vpc-id "$VPC_ID" \
  --query GroupId \
  --output text \
  --region "$REGION")

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export CVPN_SG_ID="$CVPN_SG_ID"
EOF

# private EC2 보안 그룹에 Client VPN endpoint SG를 source로 허용합니다.
# 이미 같은 규칙이 있으면 오류가 날 수 있으므로 || true로 다음 단계가 계속 진행되게 합니다.
aws ec2 authorize-security-group-ingress \
  --group-id "$PRIVATE_INSTANCE_SG_ID" \
  --ip-permissions "IpProtocol=icmp,FromPort=-1,ToPort=-1,UserIdGroupPairs=[{GroupId=$CVPN_SG_ID,Description='ICMP from Client VPN endpoint SG'}]" \
  --region "$REGION" || true

aws ec2 authorize-security-group-ingress \
  --group-id "$PRIVATE_INSTANCE_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=$CVPN_SG_ID,Description='SSH from Client VPN endpoint SG'}]" \
  --region "$REGION" || true

printf 'CVPN_SG_ID=%s\n' "$CVPN_SG_ID"
```

## 5. Client VPN endpoint 생성

Client VPN endpoint, target network association, authorization rule, VPC CIDR route를 생성합니다. Endpoint는 생성 시간 동안 비용이 발생하므로 접속 테스트가 끝나면 정리 절차를 수행합니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env

# mutual certificate authentication 설정입니다.
# ClientRootCertificateChainArn에는 client 인증서를 발급한 CA chain을 지정합니다.
AUTH_OPTIONS="[{\"Type\":\"certificate-authentication\",\"MutualAuthentication\":{\"ClientRootCertificateChainArn\":\"$SERVER_CERT_ARN\"}}]"

# split tunnel Client VPN endpoint를 생성합니다.
# split tunnel이면 VPC CIDR로 가는 트래픽만 VPN으로 보내고, 일반 인터넷은 기존 WSL 경로를 사용합니다.
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

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export CVPN_ENDPOINT_ID="$CVPN_ENDPOINT_ID"
EOF

# Client VPN endpoint를 private subnet에 연결합니다.
# 이 association이 완료되어야 VPN client가 VPC 내부로 라우팅될 수 있습니다.
ASSOCIATION_ID=$(aws ec2 associate-client-vpn-target-network \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --query AssociationId \
  --output text \
  --region "$REGION")

cat >> /tmp/fa01hc-vpc-network-foundation.env <<EOF
export ASSOCIATION_ID="$ASSOCIATION_ID"
EOF

printf 'CVPN_ENDPOINT_ID=%s\nASSOCIATION_ID=%s\n' "$CVPN_ENDPOINT_ID" "$ASSOCIATION_ID"

# association은 바로 완료되지 않으므로 associated가 될 때까지 polling합니다.
for i in {1..40}; do
  ASSOC_STATUS=$(aws ec2 describe-client-vpn-target-networks \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --association-ids "$ASSOCIATION_ID" \
    --query "ClientVpnTargetNetworks[0].Status.Code" \
    --output text \
    --region "$REGION")

  echo "association=$ASSOC_STATUS"
  [ "$ASSOC_STATUS" = "associated" ] && break
  sleep 15
done

if [ "$ASSOC_STATUS" != "associated" ]; then
  echo "Client VPN target network association 상태를 확인하세요: $ASSOC_STATUS"
  exit 1
fi

aws ec2 authorize-client-vpn-ingress \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --target-network-cidr "$VPC_CIDR" \
  --authorize-all-groups \
  --region "$REGION"

# authorization rule도 active가 될 때까지 기다립니다.
for i in {1..40}; do
  AUTH_STATUS=$(aws ec2 describe-client-vpn-authorization-rules \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --query "AuthorizationRules[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
    --output text \
    --region "$REGION")

  echo "authorization=$AUTH_STATUS"
  [ "$AUTH_STATUS" = "active" ] && break
  sleep 15
done

if [ "$AUTH_STATUS" != "active" ]; then
  echo "Client VPN authorization rule 상태를 확인하세요: $AUTH_STATUS"
  exit 1
fi

ROUTE_STATUS=$(aws ec2 describe-client-vpn-routes \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --query "Routes[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
  --output text \
  --region "$REGION")

# VPC CIDR route가 자동으로 없으면 직접 추가합니다.
if [ "$ROUTE_STATUS" = "None" ]; then
  aws ec2 create-client-vpn-route \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --destination-cidr-block "$VPC_CIDR" \
    --target-vpc-subnet-id "$PRIVATE_SUBNET_ID" \
    --region "$REGION"
fi

# route가 active가 될 때까지 기다립니다.
for i in {1..40}; do
  ROUTE_STATUS=$(aws ec2 describe-client-vpn-routes \
    --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
    --query "Routes[?DestinationCidr=='$VPC_CIDR'].Status.Code | [0]" \
    --output text \
    --region "$REGION")

  echo "route=$ROUTE_STATUS"
  [ "$ROUTE_STATUS" = "active" ] && break
  sleep 15
done

if [ "$ROUTE_STATUS" != "active" ]; then
  echo "Client VPN route 상태를 확인하세요: $ROUTE_STATUS"
  exit 1
fi
```

## 6. Client VPN 설정 파일 생성

AWS에서 `.ovpn` 설정을 export하고 client certificate/private key를 inline으로 추가합니다. WSL에서는 MTU 문제를 피하기 위해 `client-config-mtu.ovpn`을 만들어 사용합니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env
cd "$REPO_DIR/$LAB_DIR"

# AWS가 생성해주는 기본 OpenVPN 설정 파일을 내려받습니다.
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --region "$REGION" \
  --query ClientConfiguration \
  --output text > client-config.ovpn

# mutual authentication에 필요한 client certificate와 private key를 설정 파일에 붙입니다.
# 이렇게 하면 OpenVPN 실행 시 별도 인증서 파일 경로를 지정하지 않아도 됩니다.
{
  echo ""
  echo "<cert>"
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' ~/fa01hc-client-vpn-ca/pki/issued/student1.domain.tld.crt
  echo "</cert>"
  echo "<key>"
  cat ~/fa01hc-client-vpn-ca/pki/private/student1.domain.tld.key
  echo "</key>"
} >> client-config.ovpn

OVPN_ENDPOINT_ID=$(sed -n 's/^remote \(cvpn-endpoint-[a-z0-9]*\)\..*/\1/p' client-config.ovpn | head -n 1)

# 설정 파일이 지금 만든 endpoint를 가리키는지 확인합니다.
# 이전 실습의 ovpn 파일을 재사용하면 연결은 되지만 다른 VPC로 들어갈 수 있습니다.
printf 'CVPN_ENDPOINT_ID=%s\nOVPN_ENDPOINT_ID=%s\n' "$CVPN_ENDPOINT_ID" "$OVPN_ENDPOINT_ID"
test "$OVPN_ENDPOINT_ID" = "$CVPN_ENDPOINT_ID"

# WSL 환경에서 SSH가 key exchange 단계에서 멈추는 경우를 피하기 위해 MTU/MSS 옵션을 추가합니다.
cp client-config.ovpn client-config-mtu.ovpn

cat >> client-config-mtu.ovpn <<'EOF'
pull-filter ignore "tun-mtu"
tun-mtu 1280
mssfix 1200
EOF

grep -E 'remote cvpn-endpoint|pull-filter|tun-mtu|mssfix' client-config-mtu.ovpn
```

## 7. WSL에서 OpenVPN으로 직접 연결

먼저 OpenVPN과 테스트 도구를 설치하고, TUN 장치와 설정 파일 endpoint를 확인합니다. 이 블록은 새 WSL 터미널에서 바로 실행해도 되도록 env 파일을 다시 불러옵니다.

```bash
ENV_FILE=/tmp/fa01hc-vpc-network-foundation.env

# 새 WSL 터미널에서는 이전 터미널의 PRIVATE_IP, KEY_FILE 같은 변수가 없습니다.
# 그래서 1번 단계에서 저장한 env 파일을 반드시 다시 불러옵니다.
if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE 파일이 없습니다. 1번 단계의 환경변수 저장 블록을 먼저 실행하세요."
  exit 1
fi

source "$ENV_FILE"

: "${REPO_DIR:?REPO_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${LAB_DIR:?LAB_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${PRIVATE_IP:?PRIVATE_IP 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${KEY_FILE:?KEY_FILE 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"

cd "$REPO_DIR/$LAB_DIR"

# OpenVPN 실행과 SSH 테스트에 필요한 패키지를 설치합니다.
sudo apt update
sudo apt install -y openvpn iputils-ping openssh-client netcat-openbsd

# OpenVPN은 Linux TUN 장치를 사용합니다. WSL에서 장치가 있는지 확인합니다.
sudo modprobe tun 2>/dev/null || true
ls -l /dev/net/tun

printf 'PRIVATE_IP=%s\nKEY_FILE=%s\n' "$PRIVATE_IP" "$KEY_FILE"
sed -n 's/^remote \(cvpn-endpoint-[a-z0-9]*\)\..*/\1/p' client-config-mtu.ovpn
```

아래 명령은 VPN 연결을 유지하는 동안 터미널을 점유합니다. 로그에 `Pushed option removed by filter: 'tun-mtu 1500'`와 `mtu 1280 for tun0`가 보이면 MTU 설정이 적용된 상태입니다.

```bash
ENV_FILE=/tmp/fa01hc-vpc-network-foundation.env

# VPN 연결용 터미널도 새 터미널일 수 있으므로 env 파일을 다시 불러옵니다.
if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE 파일이 없습니다. 1번 단계의 환경변수 저장 블록을 먼저 실행하세요."
  exit 1
fi

source "$ENV_FILE"

: "${REPO_DIR:?REPO_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${LAB_DIR:?LAB_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"

cd "$REPO_DIR/$LAB_DIR"

# 이 명령은 foreground로 실행됩니다.
# SSH 테스트는 이 터미널을 닫지 말고 다른 WSL 터미널에서 진행합니다.
sudo openvpn --config client-config-mtu.ovpn
```

VPN 터미널은 그대로 두고, 다른 WSL 터미널에서 아래 블록을 실행합니다. 새 터미널에서는 환경변수가 사라지므로, `PRIVATE_IP`를 사용하기 전에 env 파일을 다시 source하고 필수 값을 검증합니다.

```bash
ENV_FILE=/tmp/fa01hc-vpc-network-foundation.env

# 이 블록은 새 WSL 터미널에서 실행합니다.
# PRIVATE_IP가 비어 있으면 route/ping/ssh 대상이 없어지므로 실행 전에 필수 값을 검증합니다.
if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE 파일이 없습니다. 1번 단계의 환경변수 저장 블록을 먼저 실행하세요."
  exit 1
fi

source "$ENV_FILE"

: "${REPO_DIR:?REPO_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${LAB_DIR:?LAB_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${PRIVATE_IP:?PRIVATE_IP 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${KEY_FILE:?KEY_FILE 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"

cd "$REPO_DIR/$LAB_DIR"

# private EC2로 가는 경로가 tun0인지 확인합니다.
ip addr show tun0
ip route get "$PRIVATE_IP"
ip route | grep default

# ping은 ICMP, nc는 TCP 22, ssh는 실제 로그인까지 확인합니다.
ping -c 4 "$PRIVATE_IP"
nc -vz "$PRIVATE_IP" 22
ssh -o IPQoS=none -o IdentitiesOnly=yes -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"
```

SSH가 실패할 때는 아래 블록으로 key, TCP 22, MTU 설정을 한 번에 확인합니다.

```bash
ENV_FILE=/tmp/fa01hc-vpc-network-foundation.env

# SSH 실패 원인이 네트워크인지, 키 파일인지, MTU인지 순서대로 확인합니다.
if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE 파일이 없습니다. 1번 단계의 환경변수 저장 블록을 먼저 실행하세요."
  exit 1
fi

source "$ENV_FILE"

: "${REPO_DIR:?REPO_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${LAB_DIR:?LAB_DIR 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${PRIVATE_IP:?PRIVATE_IP 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"
: "${KEY_FILE:?KEY_FILE 값이 비어 있습니다. $ENV_FILE 파일을 확인하세요.}"

cd "$REPO_DIR/$LAB_DIR"

# TCP 22가 열려 있어야 SSH가 가능합니다.
nc -vz "$PRIVATE_IP" 22

# key 파일이 존재하고 private key 형식인지 확인합니다.
ls -l "$KEY_FILE"
test -s "$KEY_FILE"
head -n 1 "$KEY_FILE"
chmod 400 "$KEY_FILE"

# MTU 우회 옵션이 들어 있는지 확인합니다.
grep -E 'pull-filter|tun-mtu|mssfix' client-config-mtu.ovpn

# 자세한 SSH 로그로 어느 단계에서 멈추는지 확인합니다.
ssh -vvv \
  -o IPQoS=none \
  -o IdentitiesOnly=yes \
  -o ConnectTimeout=10 \
  -i "$KEY_FILE" \
  "ec2-user@$PRIVATE_IP"
```

`nc`는 성공하지만 SSH가 key exchange 근처에서 멈추면 MTU/MSS 값을 더 낮춰 다시 연결합니다. OpenVPN 실행 터미널에서 `Ctrl+C`로 연결을 끊은 뒤 실행합니다.

```bash
# OpenVPN 실행 터미널에서 Ctrl+C로 VPN을 먼저 끊은 뒤 실행합니다.
# 더 작은 MTU/MSS로 낮춰 조각화 문제를 피합니다.
sed -i 's/^tun-mtu .*/tun-mtu 1200/' client-config-mtu.ovpn
sed -i 's/^mssfix .*/mssfix 1160/' client-config-mtu.ovpn
grep -E 'pull-filter|tun-mtu|mssfix' client-config-mtu.ovpn

sudo openvpn --config client-config-mtu.ovpn
```

VPN 연결을 끊으려면 OpenVPN을 실행 중인 터미널에서 `Ctrl+C`를 누릅니다.

## 8. 정리

WSL OpenVPN 연결을 끊은 뒤 직접 만든 Client VPN, security group, ACM certificate를 삭제합니다. 마지막으로 Terraform 리소스를 삭제합니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env

# target network association을 먼저 끊습니다.
aws ec2 disassociate-client-vpn-target-network \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --association-id "$ASSOCIATION_ID" \
  --region "$REGION"

sleep 60

# authorization rule과 private EC2 SG에 추가한 규칙을 제거합니다.
aws ec2 revoke-client-vpn-ingress \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --target-network-cidr "$VPC_CIDR" \
  --revoke-all-groups \
  --region "$REGION"

aws ec2 revoke-security-group-ingress \
  --group-id "$PRIVATE_INSTANCE_SG_ID" \
  --ip-permissions "IpProtocol=icmp,FromPort=-1,ToPort=-1,UserIdGroupPairs=[{GroupId=$CVPN_SG_ID}]" \
  --region "$REGION" || true

aws ec2 revoke-security-group-ingress \
  --group-id "$PRIVATE_INSTANCE_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=$CVPN_SG_ID}]" \
  --region "$REGION" || true

aws ec2 delete-client-vpn-endpoint \
  --client-vpn-endpoint-id "$CVPN_ENDPOINT_ID" \
  --region "$REGION"

sleep 60

# endpoint 삭제가 반영된 뒤 SG와 ACM certificate를 삭제합니다.
aws ec2 delete-security-group \
  --group-id "$CVPN_SG_ID" \
  --region "$REGION"

aws acm delete-certificate \
  --certificate-arn "$SERVER_CERT_ARN" \
  --region "$REGION"

# Terraform이 만든 VPC, subnet, EC2, SSH key를 삭제합니다.
cd "$REPO_DIR/$LAB_DIR"
terraform destroy -auto-approve
```

## 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| VPN endpoint가 오래 걸림 | endpoint와 target network association 상태가 available이 될 때까지 기다립니다. |
| VPN은 연결됐지만 ping 실패 | `client-config-mtu.ovpn`이 가리키는 실제 endpoint ID를 확인하고, 그 endpoint의 authorization rule, Client VPN endpoint SG, private EC2 SG의 Client CIDR 허용을 확인합니다. |
| VPN은 연결됐지만 다른 private IP만 실패 | `/tmp/fa01hc-vpc-network-foundation.env`, `terraform output`, 실제 AWS 리소스가 같은 VPC를 가리키는지 확인합니다. 이전 실습의 endpoint/config를 재사용하면 같은 `10.60.0.0/16` CIDR이어도 다른 VPC로 라우팅될 수 있습니다. |
| route/auth가 active인데 ping 실패 | private EC2 security group에 Client VPN endpoint security group이 source로 허용되어 있는지 확인합니다. |
| SSH가 timeout | `nc -vz "$PRIVATE_IP" 22`로 TCP 22 연결을 확인하고, private EC2 SG의 Client CIDR 또는 Client VPN endpoint SG 허용을 확인합니다. |
| `nc`는 성공하지만 SSH가 `expecting SSH2_MSG_KEX_ECDH_REPLY`에서 멈춤 | `client-config-mtu.ovpn`에 `pull-filter ignore "tun-mtu"`, `tun-mtu 1280`, `mssfix 1200`을 추가해 다시 연결합니다. `PUSH_REPLY`에 `tun-mtu 1500`이 계속 보이면 MTU push를 아직 무시하지 못한 상태입니다. |
| `ssh -vvv`에 `identity file ... type -1`이 보임 | `KEY_FILE` 경로가 틀렸거나 파일이 없습니다. `ls -l "$KEY_FILE"`과 `head -n 1 "$KEY_FILE"`로 private key 파일인지 확인합니다. |
| SSH가 Permission denied | `ssh -o IdentitiesOnly=yes -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"` 형식인지 확인합니다. 그래도 실패하면 `aws ec2 describe-key-pairs --key-names "$(terraform output -raw ssh_key_pair_name)" --query "KeyPairs[0].KeyFingerprint" --output text --region "$REGION"` 결과와 `ssh-keygen -yf "$KEY_FILE" \| ssh-keygen -lf - -E md5` 결과가 같은지 비교합니다. |
| private key 권한 오류 | `chmod 400 "$KEY_FILE"`을 실행합니다. |
| WSL OpenVPN에서 접속 실패 | `ip addr show tun0`, `ip route get "$PRIVATE_IP"`로 VPN 경로가 `tun0`인지 확인합니다. |
| ping 실패가 계속됨 | Client VPN route table에 VPC CIDR route가 있는지 확인하고, 없으면 `create-client-vpn-route`로 추가합니다. |
| 특정 PC에서만 VPN 경로가 이상함 | 로컬 LAN, WSL, Docker 대역이 Client CIDR `172.16.0.0/22`와 겹치지 않는지 확인합니다. 겹치면 `terraform.tfvars`의 `client_vpn_client_cidr_block`을 다른 `/22` 대역으로 바꾼 뒤 VPC foundation부터 다시 생성합니다. |
| 리소스 삭제 실패 | VPN client 연결을 끊고 association 삭제가 끝난 뒤 endpoint와 SG를 삭제합니다. |

Client VPN route와 authorization rule을 확인하고, 누락된 rule/route를 보강할 때는 아래 블록을 사용합니다.

```bash
source /tmp/fa01hc-vpc-network-foundation.env
cd "$REPO_DIR/$LAB_DIR"

OVPN_ENDPOINT_ID=$(sed -n 's/^remote \(cvpn-endpoint-[a-z0-9]*\)\..*/\1/p' client-config-mtu.ovpn | head -n 1)
printf 'OVPN_ENDPOINT_ID=%s\n' "$OVPN_ENDPOINT_ID"

aws ec2 describe-client-vpn-routes \
  --client-vpn-endpoint-id "$OVPN_ENDPOINT_ID" \
  --query "Routes[].{Destination:DestinationCidr,TargetSubnet:TargetSubnet,Type:Type,Status:Status.Code}" \
  --output table \
  --region "$REGION"

aws ec2 describe-client-vpn-authorization-rules \
  --client-vpn-endpoint-id "$OVPN_ENDPOINT_ID" \
  --query "AuthorizationRules[].{Destination:DestinationCidr,AllGroups:AuthorizeAllGroups,GroupId:AccessGroupId,Status:Status.Code}" \
  --output table \
  --region "$REGION"

aws ec2 authorize-client-vpn-ingress \
  --client-vpn-endpoint-id "$OVPN_ENDPOINT_ID" \
  --target-network-cidr "$VPC_CIDR" \
  --authorize-all-groups \
  --region "$REGION" || true

aws ec2 create-client-vpn-route \
  --client-vpn-endpoint-id "$OVPN_ENDPOINT_ID" \
  --destination-cidr-block "$VPC_CIDR" \
  --target-vpc-subnet-id "$PRIVATE_SUBNET_ID" \
  --region "$REGION" || true
```

참고 문서:

- [AWS Client VPN mutual authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/mutual.html)
- [AWS Client VPN client configuration export](https://docs.aws.amazon.com/cli/latest/reference/ec2/export-client-vpn-client-configuration.html)

# VPN 구성해서 접속하기

이 문서는 `terraform/fa01hc/common/01-vpc-network-foundation`에서 AWS Client VPN을 켜고, Windows 또는 WSL 환경에서 private EC2에 접속하는 실습 가이드입니다.

기본 Terraform 구성은 비용과 인증서 준비 문제 때문에 Client VPN을 비활성화합니다. 같은 디렉토리에서 인증서를 준비한 뒤 `enable_client_vpn = true`로 바꿔 진행합니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| VPN 방식 | AWS Client VPN |
| 인증 방식 | Mutual certificate authentication |
| Client CIDR | `172.16.0.0/22` |
| 접속 대상 | Private EC2의 private IP |
| 리전 | `us-east-1` |

## 1. 사전 준비

Windows PC 기준으로 다음을 준비합니다.

| 도구 | 설치 위치 | 용도 |
| --- | --- | --- |
| AWS CLI v2 | Windows 또는 WSL | ACM 인증서 import, VPN 설정 export |
| Terraform | Windows 또는 WSL | 실습 VPC와 Client VPN 생성 |
| OpenSSH client | Windows 또는 WSL | private EC2 SSH 접속 |
| AWS VPN Client 또는 OpenVPN client | Windows | `.ovpn` 파일 import 및 연결 |
| EasyRSA | WSL 권장 | 실습용 CA, server/client certificate 생성 |

실습용 인증서는 WSL에서 만드는 흐름을 권장합니다. 운영 환경에서는 조직의 PKI 절차를 따릅니다.

## 2. 실습용 인증서 생성

WSL에서 실행합니다.

```bash
sudo apt update
sudo apt install -y easy-rsa
make-cadir ~/fa01hc-client-vpn-ca
cd ~/fa01hc-client-vpn-ca

./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full student1.domain.tld nopass
```

생성되는 주요 파일은 다음과 같습니다.

| 파일 | 용도 |
| --- | --- |
| `pki/ca.crt` | Root CA certificate |
| `pki/issued/server.crt` | Client VPN server certificate |
| `pki/private/server.key` | Client VPN server private key |
| `pki/issued/student1.domain.tld.crt` | 수강생 client certificate |
| `pki/private/student1.domain.tld.key` | 수강생 client private key |

## 3. 서버 인증서를 ACM에 등록

WSL에서 실행합니다.

```bash
cd ~/fa01hc-client-vpn-ca

SERVER_CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://pki/issued/server.crt \
  --private-key fileb://pki/private/server.key \
  --certificate-chain fileb://pki/ca.crt \
  --region us-east-1 \
  --query CertificateArn \
  --output text)

echo "$SERVER_CERT_ARN"
```

server certificate와 client certificate가 같은 CA에서 발급되었으므로, 이 Terraform 프로젝트는 `client_vpn_root_certificate_chain_arn`을 `null`로 두면 server certificate ARN을 root certificate chain ARN으로 같이 사용합니다.

## 4. Terraform 변수 변경

`terraform/fa01hc/common/01-vpc-network-foundation/terraform.tfvars`에서 Client VPN을 켭니다.

```hcl
enable_client_vpn = true

client_vpn_server_certificate_arn     = "arn:aws:acm:us-east-1:111122223333:certificate/..."
client_vpn_root_certificate_chain_arn = null
```

또는 파일을 바꾸지 않고 apply 시점에 변수로 넘길 수 있습니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation apply \
  -var="enable_client_vpn=true" \
  -var="client_vpn_server_certificate_arn=$SERVER_CERT_ARN"
```

## 5. Client VPN 생성 확인

적용 후 출력값을 확인합니다.

```bash
cd terraform/fa01hc/common/01-vpc-network-foundation

VPN_ENDPOINT_ID=$(terraform output -raw client_vpn_endpoint_id)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
KEY_FILE=$(terraform output -raw ssh_private_key_file)

terraform output client_vpn_endpoint_dns_name
terraform output private_instance_private_ip
```

콘솔에서는 다음 항목을 확인합니다.

| 화면 | 확인할 내용 |
| --- | --- |
| VPC > Client VPN endpoints | Endpoint 상태가 `Available`인지 확인 |
| Target network associations | private subnet association이 생성되었는지 확인 |
| Authorization rules | VPC CIDR `10.60.0.0/16` 접근이 허용되어 있는지 확인 |
| Security groups | Client VPN SG egress가 VPC CIDR을 허용하는지 확인 |
| EC2 security group | Client CIDR `172.16.0.0/22`에서 ICMP/SSH가 허용되는지 확인 |

## 6. Client VPN 설정 파일 생성

AWS에서 client configuration을 내려받습니다.

```bash
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id "$VPN_ENDPOINT_ID" \
  --region us-east-1 \
  --query ClientConfiguration \
  --output text > client-config.ovpn
```

수강생 client certificate와 private key를 `.ovpn` 파일 끝에 추가합니다.

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

Windows 클라이언트로 옮기기 쉽게 파일 위치를 확인합니다.

```bash
pwd
ls -l client-config.ovpn
```

WSL 파일은 Windows Explorer에서 `\\wsl$` 경로로 접근할 수 있습니다.

## 7. Windows에서 VPN 연결

1. AWS VPN Client 또는 OpenVPN client를 설치합니다.
2. `client-config.ovpn` 파일을 import합니다.
3. 프로필을 선택하고 Connect를 누릅니다.
4. 연결 상태가 Connected인지 확인합니다.

PowerShell에서 private EC2가 보이는지 확인합니다.

```powershell
$PRIVATE_IP = terraform output -raw private_instance_private_ip
ping $PRIVATE_IP
```

SSH로 접속합니다.

```powershell
ssh -i C:\path\to\fa01hc-vpc-network-foundation-key.pem ec2-user@$PRIVATE_IP
```

## 8. WSL에서 접속 확인

Windows에서 VPN을 연결한 뒤 WSL에서 다음을 실행합니다.

```bash
cd terraform/fa01hc/common/01-vpc-network-foundation

PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
KEY_FILE=$(terraform output -raw ssh_private_key_file)
chmod 400 "$KEY_FILE"

ping -c 4 "$PRIVATE_IP"
ssh -i "$KEY_FILE" "ec2-user@$PRIVATE_IP"
```

WSL2에서 Windows VPN 경로가 바로 반영되지 않으면 Windows PowerShell에서 먼저 ping을 테스트합니다. PowerShell에서는 되는데 WSL에서 안 되면 아래 명령으로 WSL을 재시작한 뒤 다시 확인합니다.

```powershell
wsl --shutdown
```

## 9. 접속 후 확인

EC2에 SSH로 들어간 뒤 private 네트워크와 운영체제를 확인합니다.

```bash
hostname -I
cat /etc/os-release
exit
```

Client VPN을 통해 접속한 SSH는 Session Manager 프록시가 아니라 VPC private IP로 직접 들어가는 흐름입니다.

## 10. 정리

1. Windows VPN client에서 연결을 끊습니다.
2. Terraform으로 AWS 리소스를 삭제합니다.

`terraform.tfvars`에 인증서 ARN을 저장했다면 다음처럼 삭제합니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation destroy
```

apply 시점에 `-var`로 넘겼다면 destroy에도 같은 값을 넘깁니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation destroy \
  -var="enable_client_vpn=true" \
  -var="client_vpn_server_certificate_arn=$SERVER_CERT_ARN"
```

3. ACM에 올린 실습용 인증서를 삭제합니다.

```bash
aws acm delete-certificate \
  --certificate-arn "$SERVER_CERT_ARN" \
  --region us-east-1
```

`terraform.tfvars`를 수정했다면 실습 후 다시 기본값으로 돌립니다.

```hcl
enable_client_vpn = false

client_vpn_server_certificate_arn     = null
client_vpn_root_certificate_chain_arn = null
```

## 11. 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| Client VPN endpoint가 오래 걸림 | Endpoint와 subnet association은 생성 후 `Available`까지 몇 분 걸릴 수 있습니다. |
| VPN은 연결됐지만 ping 실패 | Authorization rule, Client VPN SG egress, EC2 SG ingress의 Client CIDR 허용을 확인합니다. |
| SSH 실패 | private key 파일 경로, EC2 username `ec2-user`, EC2 SG 22번 허용을 확인합니다. |
| WSL에서만 접속 실패 | Windows PowerShell에서 먼저 테스트하고, 필요하면 `wsl --shutdown` 후 WSL을 다시 엽니다. |
| 인증서 오류 | server/client certificate가 같은 CA에서 발급되었는지, `.ovpn`에 client cert/key가 포함되었는지 확인합니다. |
| destroy 실패 | VPN client 연결을 끊고 다시 destroy합니다. |

참고 문서:

- [AWS Client VPN mutual authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/mutual.html)
- [AWS Client VPN client configuration export](https://docs.aws.amazon.com/cli/latest/reference/ec2/export-client-vpn-client-configuration.html)

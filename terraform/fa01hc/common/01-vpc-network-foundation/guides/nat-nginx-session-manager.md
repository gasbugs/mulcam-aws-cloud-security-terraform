# NAT Gateway 구성해서 nginx 설치하기

이 문서는 `terraform/fa01hc/common/01-vpc-network-foundation`에서 만든 NAT Gateway 경로를 확인하고, private EC2에 Session Manager로 접속해 nginx를 설치하는 실습 가이드입니다.

private EC2에는 public IP가 없습니다. 인터넷으로 직접 나가지 않고 private route table의 기본 경로를 통해 NAT Gateway로 outbound 통신합니다.

## 목표

| 항목 | 내용 |
| --- | --- |
| 접속 방식 | Session Manager shell |
| 테스트 대상 | Amazon Linux 2023 private EC2 |
| 확인 내용 | Private subnet outbound 경로, NAT Gateway, nginx 설치 |
| 리전 | `us-east-1` |

## 1. Terraform 구성 적용

기본 `terraform.tfvars`에서 NAT Gateway가 켜져 있는지 확인합니다.

```hcl
enable_nat_gateway       = true
enable_ssm_instance      = true
enable_ssm_vpc_endpoints = false
```

프로젝트 루트에서 실행합니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation init
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation apply
```

## 2. 출력값 확인

```bash
cd terraform/fa01hc/common/01-vpc-network-foundation

INSTANCE_ID=$(terraform output -raw private_instance_id)
NAT_ID=$(terraform output -raw nat_gateway_id)

terraform output private_instance_private_ip
terraform output private_route_table_ids
terraform output public_route_table_id
```

Windows PowerShell에서는 다음처럼 저장합니다.

```powershell
$INSTANCE_ID = terraform output -raw private_instance_id
$NAT_ID = terraform output -raw nat_gateway_id
```

## 3. 콘솔에서 NAT Gateway 경로 확인

AWS Console에서 `us-east-1` 리전을 선택하고 VPC 콘솔로 이동합니다.

| 화면 | 확인할 내용 |
| --- | --- |
| NAT Gateways | `fa01hc-vpc-network-foundation-nat` 상태가 `Available`인지 확인 |
| Elastic IPs | NAT Gateway에 Elastic IP가 연결되어 있는지 확인 |
| Route tables | private route table에 `0.0.0.0/0 -> nat-...` 경로가 있는지 확인 |
| Subnets | NAT Gateway는 public subnet, EC2는 private subnet에 있는지 확인 |
| EC2 Instances | private EC2에 public IPv4 address가 없는지 확인 |

AWS CLI로 확인하려면 다음 명령을 사용합니다.

```bash
aws ec2 describe-nat-gateways \
  --nat-gateway-ids "$NAT_ID" \
  --query "NatGateways[0].{State:State,SubnetId:SubnetId,PublicIp:NatGatewayAddresses[0].PublicIp}" \
  --output table \
  --region us-east-1
```

private EC2에 public IP가 없는지도 확인합니다.

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].{PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SubnetId:SubnetId}" \
  --output table \
  --region us-east-1
```

## 4. Session Manager로 EC2 접속

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region us-east-1
```

접속 후 EC2 내부에서 Amazon Linux 2023인지 확인합니다.

```bash
cat /etc/os-release
```

## 5. NAT Gateway outbound 테스트

EC2 내부에서 외부 HTTPS 호출을 실행합니다.

```bash
curl -s https://checkip.amazonaws.com
```

출력되는 IP는 private EC2의 IP가 아니라 NAT Gateway의 Elastic IP입니다. 이 값이 보이면 private subnet에서 NAT Gateway를 통해 인터넷 outbound 통신이 되는 상태입니다.

## 6. nginx 설치 및 실행

EC2 내부에서 실행합니다.

```bash
sudo dnf clean all
sudo dnf install -y nginx
sudo systemctl enable --now nginx
systemctl status nginx --no-pager
```

EC2 내부에서 로컬 루프백으로 nginx 응답을 확인합니다.

```bash
curl -I http://127.0.0.1
```

`HTTP/1.1 200 OK` 또는 `HTTP/1.1 403 Forbidden`이 보이면 nginx가 실행 중입니다. 기본 페이지 파일 권한이나 index 파일 상태에 따라 상태 코드는 달라질 수 있지만, nginx 서버가 응답하면 실습 목적은 달성한 것입니다.

## 7. 왜 브라우저에서 바로 열리지 않는가

이 EC2는 private subnet에 있고 public IP가 없습니다. 보안 그룹도 외부 인터넷 inbound를 허용하지 않습니다. 따라서 수강생 PC 브라우저에서 `http://<private-ip>`로 바로 접근할 수 없습니다.

웹 접속까지 확인하려면 다음 중 하나가 필요합니다.

| 방법 | 설명 |
| --- | --- |
| Session Manager port forwarding | 로컬 포트를 EC2의 80번 포트로 전달 |
| Client VPN | 수강생 PC를 VPC 내부 경로에 연결 |
| Load Balancer | public ALB를 별도로 구성 |

이 실습에서는 NAT Gateway outbound와 패키지 설치 확인이 목표입니다.

## 8. nginx 정리

EC2 내부에서 nginx만 제거하려면 다음 명령을 사용합니다.

```bash
sudo systemctl disable --now nginx
sudo dnf remove -y nginx
```

전체 AWS 리소스를 정리하려면 로컬 터미널에서 Terraform destroy를 실행합니다.

```bash
terraform -chdir=terraform/fa01hc/common/01-vpc-network-foundation destroy
```

## 9. 문제 해결

| 증상 | 확인할 내용 |
| --- | --- |
| `dnf install`이 실패함 | NAT Gateway 상태가 `Available`인지, private route table의 `0.0.0.0/0` 경로가 NAT Gateway인지 확인합니다. |
| `curl https://checkip.amazonaws.com` 실패 | 보안 그룹 egress, NAT Gateway, public route table의 Internet Gateway 경로를 확인합니다. |
| Session Manager 접속 실패 | EC2 IAM role에 `AmazonSSMManagedInstanceCore`가 붙어 있는지, SSM Agent가 online인지 확인합니다. |
| 브라우저에서 nginx가 안 열림 | 정상입니다. EC2는 public inbound를 열지 않는 private 서버입니다. |

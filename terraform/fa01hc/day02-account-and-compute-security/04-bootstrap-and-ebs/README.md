# 2일차 / 부트스트랩, EBS 기본 기능 이해

배포 리소스:

- Amazon Linux 2023 EC2 인스턴스
- `user_data` 기반 Apache 부트스트랩
- 암호화된 root volume
- 별도 암호화 EBS data volume과 attachment

`terraform.tfvars`의 `vpc_id`, `subnet_id`를 실습 VPC 값으로 바꾼 뒤 실행합니다.

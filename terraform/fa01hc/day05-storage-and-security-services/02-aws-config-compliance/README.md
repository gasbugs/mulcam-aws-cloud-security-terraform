# AWS Config Compliance

FA01HC 5일차 AWS 보안 서비스 이해 단원 중 "AWS Config를 활용한 규정 준수" 실습입니다.

## 배포 자원

- AWS Config 구성 레코더
- AWS Config Delivery Channel
- Config 스냅샷 저장용 S3 버킷
- Config 서비스 IAM Role
- AWS 관리형 Config Rules

## 확인 포인트

1. AWS Config 콘솔에서 레코딩 상태를 확인합니다.
2. 관리형 규칙의 `Compliant`/`Noncompliant` 평가 결과를 확인합니다.
3. 일부 리소스를 의도적으로 규칙에 맞지 않게 만든 뒤 재평가 흐름을 설명합니다.

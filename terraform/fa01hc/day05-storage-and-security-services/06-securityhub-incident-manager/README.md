# Security Hub and Incident Manager

FA01HC 5일차 AWS 보안 서비스 이해 단원 중 "SecurityHub를 활용한 보안 상태 통합 보기, Incident Manager를 활용한 대응 계획 수립" 실습입니다.

## 배포 자원

- AWS Security Hub 계정 활성화
- AWS Foundational Security Best Practices 표준 구독
- 고위험 Security Hub Finding 라우팅용 EventBridge Rule
- 알림용 SNS Topic
- Systems Manager Incident Manager Replication Set
- Incident Manager Response Plan

## 확인 포인트

1. Security Hub 콘솔에서 표준 구독과 Findings 집계를 확인합니다.
2. HIGH/CRITICAL Finding 이벤트가 EventBridge Rule에 매칭되는 구조를 설명합니다.
3. Incident Manager Response Plan에서 사고 제목, Impact, 알림 대상을 확인합니다.

## 주의

Incident Manager Replication Set은 계정 단위 설정에 가깝습니다. 이미 Incident Manager를 운영 중인 계정에서는 기존 설정과 충돌하지 않도록 실습 계정을 분리하세요.

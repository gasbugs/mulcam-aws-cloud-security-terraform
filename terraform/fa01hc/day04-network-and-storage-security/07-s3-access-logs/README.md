# S3 Access Logs

FA01HC 4일차 저장소 보안 단원 중 "S3 액세스 로그 기록" 실습입니다.

## 배포 자원

- 로그 대상 S3 버킷
- 서버 액세스 로그가 켜진 원본 S3 버킷
- S3 Public Access Block
- Bucket owner enforced 소유권 제어
- 기본 SSE-S3 암호화
- 로그 전달용 버킷 정책

## 확인 포인트

1. 원본 버킷에 객체를 업로드하고 다운로드합니다.
2. 로그 버킷의 `AWSLogs/<account-id>/` prefix에 서버 액세스 로그가 생성되는지 확인합니다.
3. 로그가 즉시 생성되지 않을 수 있으므로 수 분에서 수십 분 정도 기다립니다.

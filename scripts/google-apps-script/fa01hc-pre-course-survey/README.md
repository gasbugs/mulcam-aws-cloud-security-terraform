# FA01HC 사전 설문 Google Apps Script

AWS 클라우드 보안 실습 과정(FA01HC)을 시작하기 전에 수강생의 AWS, Terraform, 네트워크, 보안, 실습 환경 준비 상태를 확인하는 Google Form을 자동 생성합니다.

## 생성되는 항목

- 수강생용 Google Form
- 응답 저장용 Google Spreadsheet
- 응답 시트 안의 `강사용 안내` 탭
- Apps Script 로그의 설문 편집 URL, 응답 URL, 응답 시트 URL

## 실행 방법

1. [Google Apps Script](https://script.google.com/)로 이동합니다.
2. **새 프로젝트**를 만듭니다.
3. 기본 `Code.gs` 내용을 이 디렉토리의 `Code.gs` 내용으로 교체합니다.
4. 프로젝트 설정에서 `appsscript.json` 표시를 켠 뒤, 이 디렉토리의 `appsscript.json` 내용으로 교체합니다.
5. `Code.gs` 상단의 `CONFIG`를 필요에 맞게 수정합니다.

```javascript
const CONFIG = {
  courseCode: 'FA01HC',
  courseName: 'AWS 클라우드 보안 실습',
  timeZone: 'Asia/Seoul',
  instructorEmail: 'ilsunchoi@cloudsecuritylab.co.kr',
  collectEmail: true,
  limitOneResponsePerUser: false,
  sendInstructorEmail: false,
};
```

6. 함수 선택 드롭다운에서 `main`을 선택하고 실행합니다.
7. 최초 실행 시 Google 권한 승인을 진행합니다.
8. **실행 로그**에서 아래 URL을 확인합니다.

```text
Form edit URL
Form response URL
Response spreadsheet URL
```

수강생에게는 `Form response URL`만 공유합니다.

## 이메일 발송 옵션

`CONFIG.sendInstructorEmail`을 `true`로 바꾸면 `main()` 실행 후 강사 이메일로 설문 링크를 발송합니다.

이미 생성한 최신 설문 링크만 다시 보내려면 Apps Script에서 `sendLatestSurveyLinkToInstructor` 함수를 실행합니다.

## 설문 문항 구성

| 섹션 | 주요 문항 |
| --- | --- |
| 기본 정보 | 이름, 소속, 부서/담당 업무, 현재 역할 |
| 기술 경험 | AWS 경험, Terraform/IaC 경험, IAM/VPC/보안 서비스 이해도 |
| 실습 환경 | OS, 설치 도구, AWS 계정 준비 상태, 환경 제약 |
| 기대 사항 | CLI 숙련도, 진단 경험, 선호 진행 방식, 기대 내용 |
| 응답 활용 동의 | 강의 운영과 실습 지원 목적 활용 동의 |

## 운영 권장안

- 강의 3~7일 전에 설문 링크를 수강생에게 전달합니다.
- 강의 전날 18:00를 응답 마감으로 안내합니다.
- 응답 시트에서 아래 항목을 먼저 확인합니다.
  - AWS 계정 접근 미확인
  - Terraform, AWS CLI, Git 미설치
  - WSL/VPN/관리자 권한 제한
  - AWS 또는 Terraform 초급 비율
  - 관심 주제와 기대 사항

## 참고

이 스크립트는 AWS 리소스를 생성하지 않습니다. Google Form과 Google Spreadsheet만 생성합니다.

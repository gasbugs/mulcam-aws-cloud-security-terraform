/**
 * FA01HC AWS Cloud Security Terraform Labs pre-course survey generator.
 *
 * Run main() in Google Apps Script to create a Google Form and response sheet.
 */

const CONFIG = {
  courseCode: 'FA01HC',
  courseName: 'AWS 클라우드 보안 실습',
  timeZone: 'Asia/Seoul',
  instructorEmail: 'ilsunchoi@cloudsecuritylab.co.kr',
  collectEmail: true,
  limitOneResponsePerUser: false,
  sendInstructorEmail: false,
};

function main() {
  const result = createPreCourseSurvey(CONFIG);
  logSurveyResult_(result);

  if (CONFIG.sendInstructorEmail) {
    sendSurveyLinkEmail_(result, CONFIG);
  }

  return result;
}

function createPreCourseSurvey(config) {
  const createdAt = new Date();
  const stamp = Utilities.formatDate(createdAt, config.timeZone, 'yyyyMMdd-HHmm');
  const formTitle = `${config.courseCode} ${config.courseName} 사전 설문 (${stamp})`;
  const spreadsheetTitle = `${config.courseCode} 사전 설문 응답 (${stamp})`;

  const form = FormApp.create(formTitle);
  form.setDescription([
    '이 설문은 수강생의 AWS, 보안, 네트워크, Terraform 경험을 확인하고 실습 난이도를 조정하기 위한 사전 설문입니다.',
    '응답 내용은 강의 운영과 실습 지원 목적으로만 사용됩니다.',
  ].join('\n\n'));
  form.setCollectEmail(config.collectEmail);
  form.setLimitOneResponsePerUser(config.limitOneResponsePerUser);
  form.setAllowResponseEdits(true);
  form.setPublishingSummary(false);
  form.setConfirmationMessage('응답이 제출되었습니다. 강의 전 실습 환경 준비 안내를 확인해 주세요.');

  const spreadsheet = SpreadsheetApp.create(spreadsheetTitle);
  form.setDestination(FormApp.DestinationType.SPREADSHEET, spreadsheet.getId());

  addBasicInfoSection_(form);
  addExperienceSection_(form);
  addEnvironmentSection_(form);
  addCourseExpectationSection_(form);
  addConsentSection_(form);
  addInstructorSheet_(spreadsheet, form, config, createdAt);

  const result = {
    formId: form.getId(),
    formTitle,
    editUrl: form.getEditUrl(),
    publishedUrl: form.getPublishedUrl(),
    spreadsheetId: spreadsheet.getId(),
    spreadsheetUrl: spreadsheet.getUrl(),
    createdAt: createdAt.toISOString(),
  };

  PropertiesService.getScriptProperties().setProperties({
    LATEST_FORM_ID: result.formId,
    LATEST_FORM_TITLE: result.formTitle,
    LATEST_FORM_EDIT_URL: result.editUrl,
    LATEST_FORM_PUBLISHED_URL: result.publishedUrl,
    LATEST_SPREADSHEET_ID: result.spreadsheetId,
    LATEST_SPREADSHEET_URL: result.spreadsheetUrl,
    LATEST_CREATED_AT: result.createdAt,
  }, true);

  return result;
}

function addBasicInfoSection_(form) {
  form.addSectionHeaderItem()
    .setTitle('1. 기본 정보')
    .setHelpText('강의 운영과 실습 지원을 위한 기본 정보를 입력합니다.');

  form.addTextItem()
    .setTitle('이름')
    .setRequired(true);

  form.addTextItem()
    .setTitle('소속 회사/기관')
    .setRequired(true);

  form.addTextItem()
    .setTitle('부서 또는 담당 업무')
    .setRequired(false);

  addChoice_(form, '현재 역할에 가장 가까운 항목을 선택해 주세요.', [
    '인프라/클라우드 운영',
    '보안/정보보호',
    '개발/DevOps',
    '시스템/네트워크 엔지니어',
    '기획/관리',
    '학생/취업 준비',
    '기타',
  ], true);
}

function addExperienceSection_(form) {
  form.addPageBreakItem()
    .setTitle('2. 기술 경험')
    .setHelpText('강의 속도와 실습 보조 범위를 조정하기 위한 문항입니다.');

  addChoice_(form, 'AWS 사용 경험은 어느 정도인가요?', [
    '처음 사용한다',
    '콘솔에서 기본 서비스만 사용해 봤다',
    'EC2, VPC, S3 등 주요 서비스를 직접 구성해 봤다',
    '운영 환경에서 AWS 인프라를 관리해 봤다',
    'AWS 보안/거버넌스까지 운영해 봤다',
  ], true);

  addChoice_(form, 'Terraform 또는 IaC 사용 경험은 어느 정도인가요?', [
    '처음 사용한다',
    '기본 예제를 실행해 봤다',
    '모듈, tfvars, remote state를 사용해 봤다',
    '팀/운영 환경에서 Terraform을 사용해 봤다',
    'Terraform 코드 리뷰 또는 표준화를 해 봤다',
  ], true);

  addGrid_(form, '아래 항목별 현재 이해도를 선택해 주세요.', [
    'IAM 사용자/역할/정책',
    'VPC, Subnet, Route Table',
    'Security Group과 NACL',
    'EC2, S3, RDS 기본 운영',
    'CloudTrail, CloudWatch',
    'GuardDuty, Security Hub, Inspector, Macie',
    'VPN, TGW, Network Firewall',
  ], [
    '1: 거의 모름',
    '2: 개념만 이해',
    '3: 실습 경험 있음',
    '4: 업무 적용 가능',
    '5: 다른 사람에게 설명 가능',
  ], true);

  addCheckbox_(form, '관심 있거나 더 다뤄보고 싶은 주제를 선택해 주세요.', [
    'IAM 접근 제어와 감사',
    'VPC 네트워크 보안',
    'S3/RDS/KMS 저장소 보안',
    'CloudTrail/CloudWatch 기반 탐지',
    'GuardDuty/Security Hub/Inspector/Macie',
    'Network Firewall, TGW, VPN',
    '사고 대응과 포렌식 흐름',
    'Terraform 실습 구조와 자동화',
  ], false);
}

function addEnvironmentSection_(form) {
  form.addPageBreakItem()
    .setTitle('3. 실습 환경 준비 상태')
    .setHelpText('실습 당일 환경 문제를 줄이기 위한 점검 항목입니다.');

  addChoice_(form, '실습에 사용할 주 OS를 선택해 주세요.', [
    'Windows 10/11',
    'Windows + WSL',
    'macOS',
    'Linux',
    '아직 미정',
  ], true);

  addCheckbox_(form, '이미 설치했거나 사용할 수 있는 도구를 모두 선택해 주세요.', [
    'AWS CLI v2',
    'Terraform',
    'Git',
    'OpenSSH client',
    'VS Code 또는 코드 편집기',
    'WSL Ubuntu',
    'AWS VPN Client 또는 OpenVPN',
    'Session Manager plugin',
  ], false);

  addChoice_(form, 'AWS 실습 계정 접근 준비 상태를 선택해 주세요.', [
    '계정/자격 증명을 받았고 로그인까지 확인했다',
    '계정/자격 증명은 받았지만 아직 로그인하지 않았다',
    '아직 계정/자격 증명을 받지 못했다',
    '개인 AWS 계정을 사용할 예정이다',
    '잘 모르겠다',
  ], true);

  form.addParagraphTextItem()
    .setTitle('실습 환경에서 우려되는 점이 있다면 적어주세요.')
    .setHelpText('예: 회사 PC 보안 정책, VPN 설치 제한, 관리자 권한 없음, WSL 사용 불가 등')
    .setRequired(false);
}

function addCourseExpectationSection_(form) {
  form.addPageBreakItem()
    .setTitle('4. 기대 사항과 난이도')
    .setHelpText('강의 중 강조할 지점과 실습 난이도를 조정하기 위한 문항입니다.');

  addScale_(form, '터미널/CLI 명령어 사용에 얼마나 익숙한가요?', '거의 사용하지 않음', '자주 사용함');
  addScale_(form, '네트워크 장애나 보안 설정 문제를 스스로 진단하는 데 얼마나 익숙한가요?', '어려움', '익숙함');

  addChoice_(form, '강의에서 선호하는 진행 방식을 선택해 주세요.', [
    '개념 설명을 충분히 듣고 천천히 실습',
    '핵심 설명 후 바로 실습',
    '문제 해결 중심의 실습',
    '실무 사례와 토론 중심',
    '잘 모르겠다',
  ], true);

  form.addParagraphTextItem()
    .setTitle('이번 과정에서 꼭 얻어가고 싶은 내용을 적어주세요.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('강사가 미리 알고 있으면 좋은 배경이나 요청 사항이 있다면 적어주세요.')
    .setRequired(false);
}

function addConsentSection_(form) {
  form.addPageBreakItem()
    .setTitle('5. 응답 활용 동의')
    .setHelpText('응답 내용은 강의 운영과 실습 지원 목적 외에는 사용하지 않습니다.');

  addChoice_(form, '사전 설문 응답을 강의 운영과 실습 지원 목적으로 활용하는 데 동의합니다.', [
    '동의합니다',
  ], true);
}

function addChoice_(form, title, values, required) {
  const item = form.addMultipleChoiceItem()
    .setTitle(title)
    .setRequired(required);
  item.setChoiceValues(values);
  return item;
}

function addCheckbox_(form, title, values, required) {
  const item = form.addCheckboxItem()
    .setTitle(title)
    .setRequired(required);
  item.setChoiceValues(values);
  return item;
}

function addGrid_(form, title, rows, columns, required) {
  return form.addGridItem()
    .setTitle(title)
    .setRows(rows)
    .setColumns(columns)
    .setRequired(required);
}

function addScale_(form, title, lowLabel, highLabel) {
  return form.addScaleItem()
    .setTitle(title)
    .setBounds(1, 5)
    .setLabels(lowLabel, highLabel)
    .setRequired(true);
}

function addInstructorSheet_(spreadsheet, form, config, createdAt) {
  const sheet = spreadsheet.insertSheet('강사용 안내');
  sheet.getRange(1, 1, 10, 2).setValues([
    ['과정 코드', config.courseCode],
    ['과정명', config.courseName],
    ['생성 일시', Utilities.formatDate(createdAt, config.timeZone, 'yyyy-MM-dd HH:mm:ss')],
    ['설문 응답 URL', form.getPublishedUrl()],
    ['설문 편집 URL', form.getEditUrl()],
    ['응답 시트 URL', spreadsheet.getUrl()],
    ['권장 배포 시점', '강의 3~7일 전'],
    ['권장 마감 시점', '강의 전날 18:00'],
    ['응답 확인 기준', '도구 설치, AWS 접근, VPN/WSL 제약, 관심 주제'],
    ['후속 조치', '환경 미준비 수강생에게 설치 가이드와 계정 확인 안내 발송'],
  ]);
  sheet.autoResizeColumns(1, 2);
  sheet.setFrozenRows(1);
}

function sendLatestSurveyLinkToInstructor() {
  const props = PropertiesService.getScriptProperties().getProperties();
  const result = {
    formTitle: props.LATEST_FORM_TITLE || `${CONFIG.courseCode} 사전 설문`,
    editUrl: props.LATEST_FORM_EDIT_URL,
    publishedUrl: props.LATEST_FORM_PUBLISHED_URL,
    spreadsheetUrl: props.LATEST_SPREADSHEET_URL,
  };

  if (!result.publishedUrl) {
    throw new Error('먼저 main()을 실행해 설문을 생성하세요.');
  }

  sendSurveyLinkEmail_(result, CONFIG);
}

function sendSurveyLinkEmail_(result, config) {
  if (!config.instructorEmail) {
    throw new Error('CONFIG.instructorEmail을 설정하세요.');
  }

  const subject = `[${config.courseCode}] 사전 설문 링크`;
  const body = [
    `${config.courseName} 사전 설문이 준비되었습니다.`,
    '',
    `수강생 응답 URL: ${result.publishedUrl}`,
    `강사용 편집 URL: ${result.editUrl}`,
    `응답 시트 URL: ${result.spreadsheetUrl}`,
    '',
    '수강생에게는 응답 URL만 공유하세요.',
  ].join('\n');

  MailApp.sendEmail(config.instructorEmail, subject, body);
}

function logSurveyResult_(result) {
  Logger.log('Form edit URL: %s', result.editUrl);
  Logger.log('Form response URL: %s', result.publishedUrl);
  Logger.log('Response spreadsheet URL: %s', result.spreadsheetUrl);
}

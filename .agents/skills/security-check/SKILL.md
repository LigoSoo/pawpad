---
name: security-check
description: Security verification gate. Use before commit, handoff, or task completion (or on /security-check) to scan changed files and PawPad artifacts for hardcoded secrets, vulnerabilities, and risky configs. Blocks completion on critical findings.
---
# DO NOT EDIT: generated from .claude/skills/security-check/SKILL.md by pawpad-setup.ps1.
# Security Check Skill - 보안 검증 게이트

## 목적
변경 코드와 PawPad 산출물에서 secrets/민감정보, 취약점, 위험 설정을 검출. 🔴 검출 시 작업 완료 BLOCK + 조치 제안.

## 트리거
/security-check [scope]
- scope: secrets | vuln | deps | pawpad | all (미지정 시 all)
- DoD 게이트: 코드 변경 작업 완료 전 필수 (분석전용/문서전용 작업 면제)
- 권장 시점: 커밋 직전, /handoff 직전, lane done 이동 직전

## 검사 대상 결정
1. git repo: 변경 파일 (staged + unstaged + untracked)
2. 비-git: 세션 중 수정/생성 파일 + 사용자 명시 경로
3. scope=pawpad: .claude/pawpad/**, .ctxdb/**, .claude/codemap/** 전체 (변경 여부 무관)
4. 제외: .claude/pawpad/backup/**, <BUILD_OUTPUT_DIR>, <GENERATED_DIR>, lockfile

## 1. Secrets/민감정보 스캔 (scope: secrets, pawpad)
Grep 정규식, case-insensitive. 대상 파일 전체 적용.

| 패턴 (정규식) | 탐지 대상 | 심각도 |
|--------------|----------|--------|
| `AKIA[0-9A-Z]{16}` | AWS Access Key | 🔴 |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | Private Key 블록 | 🔴 |
| `eyJ[A-Za-z0-9_-]{20,}\.eyJ` | JWT 토큰 | 🔴 |
| `(api[_-]?key|secret|token|passw(or)?d|credential)\s*[:=]\s*["'][^"']{8,}["']` | 자격증명 하드코딩 할당 | 🔴 |
| `(mongodb|mysql|postgres(ql)?|redis|amqps?|mssql)://[^/\s:]+:[^@\s]+@` | 자격증명 포함 연결 문자열 | 🔴 |
| `\b\d{6}-[1-4]\d{6}\b` | 주민등록번호 패턴 | 🔴 |
| `\b01[016789]-?\d{3,4}-?\d{4}\b` | 휴대전화번호 (다건 시) | 🟡 |
| `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}` | 이메일 다건 (개인정보 목록 의심) | 🟡 |

False positive 제외 (검출에서 제거):
- placeholder: `<YOUR_*>`, `xxx`, `example`, `dummy`, `test`, `changeme`, `placeholder`
- env var 참조: `$env:`, `process.env`, `os.environ`, `${...}`, `{{...}}`
- 문서 내 패턴 설명 자체 (이 SKILL.md 등 정규식 정의부)

## 2. 취약점 체크리스트 (scope: vuln) — LLM 리뷰
변경 파일 read 후 항목별 점검:

| 항목 | 점검 내용 | 심각도 |
|------|----------|--------|
| Injection | SQL/command/eval에 외부 입력 직결합 (파라미터화 없음) | 🔴 |
| AuthN/AuthZ | 인증 누락 외부 노출 endpoint, 권한 검사 생략 | 🔴 |
| 경로 조작 | 사용자 입력 경로 직사용 (`../` 미검증, 절대경로 미차단) | 🔴 |
| Deserialization | 신뢰 불가 입력 unsafe parse (pickle, eval-JSON 등) | 🔴 |
| XSS | 미이스케이프 출력 (innerHTML, dangerouslySetInnerHTML, v-html) | 🟡 |
| 암호화 | 약한 해시(MD5/SHA1)로 비밀번호 저장, 하드코딩 IV/salt | 🟡 |
| 로깅 | 민감정보(토큰/비밀번호/개인정보) 로그 출력 | 🟡 |

## 3. 의존성/설정 점검 (scope: deps)
- 매니페스트/lockfile 변경 시: 신규 의존성 이름/출처/버전 확인 (typosquatting 의심 명칭 🔴)
- 위험 설정값:

| 패턴 | 심각도 |
|------|--------|
| `debug\s*[:=]\s*true` (운영 설정 파일) | 🟡 |
| CORS 전체 허용 (`*` origin + credentials) | 🔴 |
| TLS 검증 비활성 (`verify=false`, `rejectUnauthorized: false`, `InsecureSkipVerify`) | 🔴 |
| 과다 권한 (chmod 777, AllowAll, `0.0.0.0` 바인딩 의도 불명) | 🟡 |

## 4. PawPad 산출물 검증 (scope: pawpad)
- 1번 secrets 정규식을 .claude/pawpad/**, .ctxdb/** 전체에 적용
- 추가 점검: handoff/spec/lane/L2 파일에 실데이터 유입 여부 (고객 식별정보, 운영 로그 원문, 운영 DB 데이터) — 발견 시 🔴

## 출력 포맷
보안검증: {scope} | 파일 {N}개 | 🔴{n} 🟡{n} 🟢{n} | [PASS 또는 BLOCK]

| # | 심각도 | 파일:라인 | 항목 | 조치 |
|---|--------|----------|------|------|

마스킹 필수: 검출 값은 앞 4자 + `****`만 표시. 전체 값 출력/재인용 금지.

## 판정 규칙
- 🔴 ≥ 1 → **BLOCK**: 작업 완료 금지. 조치 제안 (env var 이관, 마스킹, .gitignore 추가, PawPad 파일 정화) → 조치 후 해당 scope 재검증
- 🟡 만 → PASS (경고 포함). gap + owner 결정을 lane에 기록
- 검출 0 → PASS

## DoD 연동
- lane `## Verification Evidence`에 1줄 기록:
  `security-check: {scope} {N}files 🔴0 🟡{n} → PASS`
- 분석전용/문서전용 작업: `not applicable: analysis-only` 면제 유지
- 🔴 발견 시 Escalation Rules (Credential required: STOP - use env var reference) 따름
- BLOCK 상태로 사용자 미응답 시: lane state=BLOCKED + reason 기록

## 원칙
- 검출 0 ≠ 안전 보장. 정규식+체크리스트 범위 내 검증임을 출력 말미에 명시
- 새 패턴 필요 시 이 SKILL.md 표에 행 추가 (단일 소스, 미러는 setup script 재생성)
- 의존성 취약점 DB 조회(CVE)는 범위 외 — 외부 도구(npm audit 등) 별도 안내만


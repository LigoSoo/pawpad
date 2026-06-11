---
name: codemap
description: Symbol location registry. Use to record or look up where feature components live without searching files; enforces owner-separated edit permissions for multi-agent work.
---
# DO NOT EDIT: generated from .claude/skills/codemap/SKILL.md by pawpad-setup.ps1.
# CodeMap Skill - Symbol Location Registry

## 목적
구현된 기능 컴포넌트 위치를 심볼 테이블로 관리.
수정/참조 시 파일 탐색 없이 즉시 위치 파악.

## 심볼 포맷
[domain]:[symbol]    [file_path]    [핵심 시그니처/타입]: [역할 1줄]
목적: 에이전트가 파일을 열지 않고 위치+시그니처+역할 파악 -> 토큰 절약. 실제 수정 시에만 해당 파일 read.
핵심/자주 만지는 심볼만 시그니처+역할 상세. 주변부는 위치만. (codemap=요약, 코드=전체. 로직 복붙 금지)

예시:
auth:login         src/features/auth/login.<ext>         Login: 로그인 화면(이메일+소셜)
db:user            src/models/user.<ext>                 User{id,name,role}: 사용자 모델
api:fetchUser      src/api/user_api.<ext>                fetchUser(id)->User: 유저 조회

## 도메인 분류
| 도메인 | 대상 |
|--------|------|
| auth   | 인증 화면, services |
| club   | (예시 도메인) |
| member | (예시 도메인) |
| db     | 데이터 모델, repository |
| api    | 외부 API 연동 |
| ui     | 공통 UI 컴포넌트 |
| core   | 공통 서비스, 유틸 |

## _index.md 구조
# MAP (data flow / 한눈 조망)   <- 모듈 흐름 다이어그램 (구조·영향범위 파악, 선택)
[레이어/화살표. 예: ui --입력--> core --결과--> render]
# HOT (최근 접근 3~5개)
[최근 심볼]
# INDEX
[전체: domain:symbol  file_path  시그니처: 역할]

## 권한 (Owner 분리)
| 작업 | 허용 |
|------|------|
| 신규 항목 추가 (append) | 누구나 (어느 lane이든) |
| 기존 항목 수정 (경로/이름 변경) | lane owner만 |
| 기존 항목 삭제 | lane owner만 |
| HOT 섹션 갱신 | 누구나 |

owner 확인: _wip.md Locks 섹션에서 해당 파일 매핑 확인.
Lock 없는 파일은 추가만 허용, 수정/삭제 시 _wip.md Locks에 임시 lock 등록 권장.

## 업데이트 규칙
| 시점 | 액션 | 누가 |
|------|------|------|
| 새 화면/컴포넌트/서비스 생성 | INDEX에 추가 | 생성한 lane |
| 파일 경로/클래스명 변경        | 해당 행 수정 | **owner만** |
| 파일 삭제                     | 해당 행 제거 | **owner만** |
| 작업 후                       | HOT 섹션 상단 | 누구나 |

## 동시 수정 충돌 방지 (하이브리드)
- 두 에이전트가 동시에 _index.md 수정 시:
  - append 충돌 -> 양쪽 라인 모두 보존
  - 명백한 중복 -> 다음 세션에서 owner가 정리
- 같은 행을 양쪽이 수정 시 -> owner가 우선, 비owner는 _wip.md에 충돌 보고

## 성장 전략
Phase A (<=80 entries): 플랫 리스트
Phase B (>80): 도메인 라우터로 전환
  # DOMAINS
  auth -> .claude/codemap/auth.md  (N entries)
  # HOT (inline)
  auth:login  src/.../login.<ext>  Login
Phase C (도메인 >30): 서브도메인 분리


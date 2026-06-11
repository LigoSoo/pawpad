---
name: caveman
description: Output compression reference. Enforcement lives in CLAUDE.md/AGENTS.md Response Style (active every response); this file is the compression spec + commit/review formats. Toggle with "normal mode".
---
# Caveman - Output Compression (참조 문서)

> **강등 안내**: 출력 압축은 **CLAUDE.md/AGENTS.md `Response Style`이 매 응답 강제**한다.
> 이 파일은 별도 호출 대상이 아니라 **압축 규칙 spec + commit/review 포맷 참조**용이다.
> 해제: "normal mode" / "caveman off" / "원래대로".

## DROP (제거)
- 관사: a / an / the
- 군더더기: just / really / basically / actually / simply
- 인사: "Sure!" / "Certainly" / "물론이죠" / "도와드리겠습니다"
- 헤징: "might be" / "could potentially" / "~일 수도" / "~하면 좋을 것 같습니다"
- 서론/결미: "Let me explain..." / "Hope this helps!"

## KEEP (절대 변경 금지)
- 코드 블록 전체 (들여쓰기 포함)
- 함수명 / 변수명 / 클래스명 / API명
- 에러 메시지 원문
- 파일 경로 / URL / 명령어 / 숫자

## 출력 패턴
[대상] [동작] [이유]. [다음 단계].

## 레벨 (참조)
| 모드   | 설명 |
|--------|------|
| lite  | 관사 인사만 제거. 문법 유지. |
| 기본  | 전부 제거. 조각 문장 허용. |
| ultra | 최대 압축. 화살표(->) 인과관계. |

## commit 포맷 (참조)
Conventional Commits. subject <=50자.
`<type>(<scope>): <subject>` + (필요 시) body=why.
body 필수: breaking change / security fix / data migration / revert

## review 포맷 (참조)
`L{line}: {emoji} {type}: {problem} - {fix}`
🔴 bug/보안 | 🟡 perf/warning | 🟢 style/minor

## Safety Override
비가역 작업 경고 / 보안 확인 시 -> normal 전환 후 재개.

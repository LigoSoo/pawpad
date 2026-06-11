# Hook Testing Checklist

PawPad (Agentic Engineering Toolkit) hook 회귀 방지 체크리스트. v2.19 CP949 콘솔 UTF-8 stdin 버그(한글 username transcript_path -> JSON 파싱 실패 -> ctx 0% 영구표시) 재발 방지가 1차 동기.

대상: `.claude/hooks/*.ps1`, `.codex/hooks/*.ps1` (+ `.sh` wrapper). 양 에이전트 런타임 공통.

## 공통 (입력/안전성)
- stdin: JSON 1개 수신 (UTF-8). 인코딩: `[Console]::OpenStandardInput()` + UTF8 디코딩 (콘솔 코드페이지 비의존).
- 실패/예외: 해당 event 계약에 맞는 safe fallback + exit 0 (agent 실행 차단 금지).
- **주의: 출력은 일률적으로 JSON/`{}`가 아니다.** event/runtime별 계약이 다름 — 아래 표 기준으로 검증.

## 출력 계약 (event/runtime별)
| runtime | event | 정상 출력 | no-op / fallback |
|---------|-------|----------|------------------|
| Claude  | statusLine       | plain text (`ctx N% (...) \| model`)                         | (해당 없음)                       |
| Claude  | SessionStart     | plain text additional context (codemap/INDEX 라우터)         | 빈 출력 가능                      |
| Claude  | UserPromptSubmit | `{hookSpecificOutput:{hookEventName,additionalContext}}` JSON | `{}` (no-match/error)             |
| Claude  | PreCompact       | plain text reminder (`=== PawPad PreCompact ===...`)            | (항상 출력)                       |
| Claude  | Stop             | block 시 `{"decision":"block","reason":...}` JSON           | **무출력 + exit 0** (no-op, `{}` 아님) |
| Codex   | lifecycle (UserPromptSubmit/Stop) | `.codex/hooks.json` 계약대로 유효 JSON object. ctxdb-inject·pre-compact는 top-level `suppressOutput:true` + `systemMessage` 1줄 포함 (TUI 노이즈 저감 선반영; Codex측 suppressOutput 미구현, openai/codex#16933) | `{}`                              |
| Claude  | `.sh` wrapper    | 위 Claude event 계약과 동일                                  | pwsh/jq 부재 시: ctxdb-inject=`hookSpecificOutput` skip, statusLine=plain `ctx n/a`, SessionStart=plain\|빈 출력, PreCompact=빈 줄, Stop=무출력 (**`{}` 아님**) |
| Codex   | `.sh` wrapper    | 위 Codex lifecycle JSON 계약과 동일                          | pwsh 부재 시: ctxdb-inject=`hookSpecificOutput` skip, SessionStart·PreCompact·Stop=`{}` |

## 체크리스트 (변경 시 수동 점검; 추후 scripts/ runner)

| # | 케이스 | 기대 결과 | 관련 버그/규칙 |
|---|--------|----------|----------------|
| 1 | `.ps1` hook scriptblock syntax parse | 파싱 통과 | 전 hook |
| 2 | `.sh` wrapper, `pwsh`/`jq` 부재 환경 | runtime별 safe fallback + exit 0 (비차단). **Claude**: ctxdb-inject=`hookSpecificOutput` skip / statusLine=plain `ctx n/a` / SessionStart=plain\|빈출력 / PreCompact=빈 줄 / Stop=무출력. **Codex**: ctxdb-inject=`hookSpecificOutput` skip / SessionStart·PreCompact·Stop=`{}`. (일률 `{}` 아님) | Unix wrapper |
| 3 | UTF-8 stdin, 한글 prompt/path(예: `김민수`) | 깨짐 없이 파싱, ctx% 정상 | **v2.19 UTF-8 버그** |
| 4 | malformed JSON stdin | event/runtime별 safe fallback + exit 0 (예외 누출 금지) — 위 "출력 계약" 표 따름. **Claude**: ctxdb-inject=`{}`\|`hookSpecificOutput` / statusLine=무출력(return) / PreCompact·SessionStart=plain / Stop=계약대로. **Codex**: SessionStart·PreCompact·Stop=`{}` | safe fallback |
| 5 | no-match prompt (ctxdb-inject) | `{}` (전체 ctxdb 로드 금지) | keyword 최소로드 |
| 6 | 같은 session 같은 keyword 2회 | 2회차 `{}` (dedupe) | session dedupe |
| 7 | Stop hook 8턴 도달 | `decision:block` checkpoint 발화 | 정기저장 |
| 8 | Stop hook 1~7턴 (Claude) | 무출력 + exit 0 (no-op, `{}` 아님) | turn-count |
| 9 | PreCompact 직후 Stop(최근 8턴 내) | checkpoint 중복 생략 | 중복 가드(last-compact) |
| 10 | L2 파일 150줄/2000토큰 초과 | split 경고 (동일 sig 재경고 throttle) | L2 분할 규칙 |
| 11 | Claude(`turn-count`) vs Codex(`codex-turn-count`) state 분리 | 상호 간섭 없음 | state 키 분리 |
| 12 | 출력 계약 (event별) | 위 "출력 계약" 표대로 event/runtime별 유효 (일률 JSON 금지: statusLine/PreCompact=plain text, Stop no-op=무출력) | 런타임 호환 |
| 13 | Codex `commandWindows`에 큰따옴표 포함 금지 | `-EncodedCommand`(base64)만 사용. Codex는 hook을 `cmd.exe /C "<command>"`(Rust std가 내부 `"`→`\"`)로 실행 → 중첩 큰따옴표는 cmd 레이어에서 깨져 ps1 미실행/exit 1. 검증: Rust 동일 spawn(`cmd /C` + `\"` 이스케이프)으로 root/하위/외부 cwd 실행 → 계약 출력 + exit 0 | **v2.20 hook exited with code 1 버그** (2026-06-10) |
| 14 | Codex ctxdb-inject/pre-compact 정상 출력 | top-level `suppressOutput:true` + `systemMessage` 1줄 포함 (additionalContext 병행). no-op `{}`에는 미포함 | Codex TUI 노이즈 저감 선반영 (openai/codex#16933) |
| 15 | Codex ctxdb-inject injectMode (pawpad-config `ctxdb.injectMode`) | pointer(기본/키 부재/오타값): additionalContext에 본문 대신 `read: .ctxdb/...` 지시 수 줄만, status=`pointer` / full: 기존 본문 주입. 양 모드 dedupe 동일 | Codex TUI 노이즈 (pointer 모드) |
| 16 | explicit fallback needle (양 런타임 ctxdb-inject) | 재개 의도어(ctxdb/context-saver/resume/handoff/이어서/재개/세션저장 등)만 발화. 프로젝트·에이전트명(pawpad/claude/codex) 포함 일반 프롬프트는 `{}` | 과발화 -> stale L2 오주입 버그 (2026-06-11) |

## 실행 패턴 (참고)
PowerShell hook을 stdin 주입으로 단독 검증:
```powershell
'{"session_id":"t1","prompt":"테스트","transcript_path":"C:\\Users\\김민수\\x.jsonl"}' |
  & pwsh -NoProfile -File .\.claude\hooks\ctxdb-inject.ps1
```
- 한글 경로/프롬프트 포함해 #3 재현.
- 출력이 해당 event 계약(위 표)대로인지 확인 — ctxdb-inject(UserPromptSubmit)는 `hookSpecificOutput` JSON 또는 `{}`. 예외 누출 없는지 확인.
- stdin 닫힘(파이프 종료)까지 hang 없는지 확인.

## 크로스플랫폼 리스크
- Windows path separator(`\`) vs Unix(`/`).
- CP949/UTF-8 콘솔 코드페이지 — stdin은 항상 UTF8 디코딩.
- timeout/hang — stdin 미종료 시 무한대기 방지.
- background/detached 프로세스 — 부모 exit 비대기.
- temp 디렉토리 경로 차이.

## 위치/갱신
- 이 문서는 doc-only. 실제 자동 테스트 runner는 repo가 git/test 가능해지면 `scripts/`에 추가.
- hook 변경(신규 케이스/버그fix) 시 해당 행 추가. 양 에이전트 공통.

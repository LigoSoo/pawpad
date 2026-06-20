# CHANGELOG v2.34 — skill rename: `memory` → `resume`

> PawPad — Agentic Engineering Toolkit. v2.33 기반. 단일 스킬 rename(가산 변경 0, 기능 동작 불변).

## 요약
`memory` 스킬을 `resume`로 rename. 이름이 "기억 저장(memory store)"으로 오해되나 실제 동작은 **세션 시작 재개(ON START) 프로토콜**(HYBRID/_wip/lane/handoff/spec/_meta/codemap read) → 동작 직결 명명으로 교정. 스킬 수 **19 불변**(rename, 신규/삭제 아님).

## 결정 (AskUserQuestion)
| 항목 | 결정 | 근거 |
|------|------|------|
| -Upgrade 마이그레이션 | **자동 이동** — 구 `memory/` dir(.claude+.agents) Move/제거 + config skills 배열 치환 | ADR-002(KMS→pawpad) 선례, 기존 사용자 무중단 |
| 하위호환 alias | **하드 rename** — `/memory` 제거, `/resume`만 | ADR-002 선례(완전 제거), alias 잔재 없이 깔끔. 기존 사용자는 -Upgrade로 흡수 |

## 변경 표면
- **live 스킬**: `.claude/skills/memory/` → `.claude/skills/resume/` (dir rename, `name:`/제목 갱신)
- **.agents 미러**: `.agents/skills/memory/` → `.agents/skills/resume/` (DO NOT EDIT 헤더 source 경로 포함 갱신)
- **config/manifest**: `.codex/config.json` skills `"memory"`→`"resume"` / `SKILLS_MANIFEST.md` 3곳
- **CLAUDE.md**: Session Protocol `-> Detail` 포인터, 자동제안 제외목록 (`AGENTS.md`는 memory 참조 0 — 변경 없음)
- **타 스킬 참조**: `review`(memory ON START→resume ON START), `to-prd`(memory skill→resume skill) — live+미러
- **wip/README.md**: lane 포맷 참조 경로
- **README/GUIDE/USAGE**: `/memory`→`/resume` 전부 + 버전 v2.33→v2.34
- **setup.ps1**: 헤더 STATUS/$ver, 임베드 skill 블록(name/title/path/Step-Begin), 임베드 $tmplClaudeMd(Detail+제외), 임베드 manifest/config/to-prd/review/wip-README + **-Upgrade 마이그레이션 pre-pass**(dir Move/제거 + config 치환, 백업 전 수행)
- **codemap**: `pawpad:resumeSkill` 항목 추가(기존 memory 항목 부재) + setupScript v2.34 노트

## -Upgrade 마이그레이션 (기존 설치)
1. `.claude\skills\memory` 존재 + `resume` 없음 → Move; 둘 다 있으면 구 `memory` 제거 (신규 `resume/`는 toolkit 재생성)
2. `.agents\skills\memory` 동일 처리
3. `.codex\config.json` skills 배열 `"memory"`→`"resume"` 텍스트 치환 (no-BOM 유지, 병합 union 시 구 항목 잔존 방지)
- 모두 백업 전 수행 → 백업은 마이그레이션 후 상태 기준 (KMS 선례 패턴)

## 비변경 (audit 보존)
backup/ · wip/done/ · sessions/ · reviews/ · handoffs/ · specs/ · docs/CHANGELOG_v2.19·v2.31 등 과거 changelog · docs/superpowers/plans/ — 과거 문서 속 `memory` 표기는 의도적 stale (ADR-002 선례). 사용자 auto-memory(Claude 기억 기능)는 pawpad 무관 — 무변경.

## 검증
- PSParser 0 (setup.ps1 파싱)
- live `.claude/skills/resume/` == `.agents/skills/resume/` 미러 (DO NOT EDIT 헤더 제외)
- 스킬 수 19 일관 (.claude == .agents == config == manifest == setup 임베드)
- 임베드 == live (skill 블록·$tmplClaudeMd Detail/제외·manifest·config)
- `.codex/config.json` no-BOM + JSON valid
- stale `skills/memory`·`/memory` 라이브 0 (audit 제외)
- security-check 🔴 0

## 리뷰 (2026-06-19)
- **PASS 100%, findings 0** — Claude 서브에이전트(Read/Grep/Glob 전용, EDR-safe) 문서형 /review 라운드트립. 10항목 직접 검증(dir rename·스킬19 일관·live/미러/임베드 동기·-Upgrade 마이그레이션 안전성·참조 동기·stale 0·회귀 없음). shell-only 항목(PSParser·BOM·EOF)은 구현 세션 PowerShell 선검증.
- codex exec 자율 리뷰는 시도했으나 이 머신 EDR이 codex의 powershell.exe 버스트를 탐지→소켓 차단(os error 10013)→모델 통신 불가로 미완(코드 무관, 환경 제약). 크로스모델 독립 리뷰가 필요하면 WSL/EDR-free 머신에서.
- request: `.claude/pawpad/reviews/skill-rename-resume-review-prompt-01.md` / result: `.claude/pawpad/reviews/skill-rename-resume-review-01.md`

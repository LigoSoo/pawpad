# CHANGELOG v2.28 — Mockup-Driven Planning

## 추가: mockup 스킬 + 흐름 자동제안 + 선택지 질문 체크박스

### 신규 스킬: mockup (count 16 → 17)
- `.claude/skills/mockup/SKILL.md` — PRD-tree를 **단일 HTML 목업**으로 투영하는 기획 시각화 게이트.
- 트리거: `/mockup [화면|all] [lo|hi]` (기본 lo-fi).
- **fidelity 2단계**: lo-fi(와이어프레임, 회색박스+라벨) / hi-fi(design 토큰 적용). 구조 안정화 시 hi-fi 자동제안.
- **Feature ID 태깅**: 화면마다 Feature ID 라벨 + 메뉴/내비 위치 표현.
- **단방향 동기**(PRD-tree = source of truth) + **drift 경고**(누락/고아 Feature ID).
- 산출물: `src/mockups/{feature-id}-mockup.html`.

### CLAUDE.md / AGENTS.md 라우팅 확장
- `## Idea → PRD Routing`에 UI/화면 기획 시 design + mockup 추천 추가.
- `### 자동제안 (단계 경계)`: PRD/PRD-tree 갱신 직후 → mockup, clarity/grill-me/grill-with-docs/to-prd 종료 시 → 다음 스킬을 **1회 추천**(강제 X). 거절 시 다음 단계 경계까지 침묵. 대상 한정(기획/설계 흐름 스킬), 나머지는 Session Protocol/hook 트리거 → 제외.
- `### 선택지 질문 = 체크박스`: 기획/설계 스킬 진행 중 선택지 N개 질문은 AskUserQuestion(체크박스)로, 자유서술·수치는 텍스트로.
- Active Skills 단계 첨자에 `design`, `mockup lo/hi` 추가.

> 자연 흐름 자동제안은 **instruction 기반**(CLAUDE.md/AGENTS.md 라우팅). hook 자동 트리거는 범위 외(일부 머신 org 정책 차단). 배포 대상 머신에서 instruction으로 동작.

### 전 표면 동기
- pawpad-setup.ps1: $ver 2.28, 헤더, 스킬 임베드(`@'...'@`), $tmplClaudeMd/$tmplAgentsMd 라우팅·Active Skills 동기, SKILLS_MANIFEST 16→17, 완료 메시지 CHANGELOG 참조.
- .codex/config.json skills 배열 + 라이브 SKILLS_MANIFEST.md + .agents/skills 미러(자동 재생성).
- codemap `_index.md`에 mockup 심볼 등록.

### 검증
- 정적/구조 검증 PASS: PSParser parse-ok 0 / 스킬 수 17 일관(.claude/skills == .agents/skills == .codex/config.json == SKILLS_MANIFEST == setup embed) / 임베디드 $tmpl == live CLAUDE·AGENTS / mockup SKILL embed == live / .agents 미러 본문 동일 / json·toml·SKILL BOM-less / hardcoded secret 0.
- behavioral smoke 실행 PASS(`/mockup all lo` 데모, src/PRD-tree.md→src/mockups/todayquest-mockup.html): 46 leaf 태깅 + drift 0/0 + 합성 drift 탐지(누락 TQ-HOME-03·고아 TQ-FAKE-99) 확인. hi-fi·-Upgrade 병합 smoke는 미실행.
- Codex 독립 리뷰(review-01, gpt-5.5 xhigh): **PASS_WITH_FIXES 92%, 코드 결함 0**. findings 3건(버전 stale 2 + changelog 과장 1) 반영.

### 프로세스
clarity PASS(34/100) → grill-me(9분기 resolved) → to-prd → 구현 lane. spec: `.claude/pawpad/specs/mockup-driven-planning.md`.

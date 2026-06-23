# Skills Manifest

프로젝트에 설치된 모든 스킬 목록. (19개)

> **환경별 활성 방식**
> - Claude Code: `/skill` slash 호출 + description 자동 트리거 둘 다 지원.
> - Codex CLI: **slash 호출 미보장**. `.agents/skills/*/SKILL.md`의 `description` 기반 **자동 트리거 중심**. 명시 호출 필요 시 "use {skill} skill"처럼 자연어로 지시.
> - caveman/lean-code는 skill이 아니라 **CLAUDE.md/AGENTS.md가 매 응답 강제**한다(아래 참조 강등 참고).
> - feature-architecture도 참조 스킬 — 실제 강제는 CLAUDE.md/AGENTS.md `Architecture Principles (Feature-First)`(신규/변경 코드만).
> - statusline은 **Claude Code 전용**(`.claude/settings.json` statusLine). Codex CLI는 statusline 메커니즘이 없어 미적용.

---

## Skill 목록

### 📍 Core Skills (상태/코드 기반)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **resume** | `.claude/skills/resume/` | WIP 상태 관리, 세션 재개(ON START) 프로토콜 |
| **codemap** | `.claude/skills/codemap/` | 심볼 위치 레지스트리, owner 분리 권한 |
| **codebase-map** | `.claude/skills/codebase-map/` | 7축 고수준 코드베이스 맵(아키텍처/구조/관례/관심사), digest-only 주입 |
| **caveman** | `.claude/skills/caveman/` | 압축 통신 모드 (참조). 실제 강제는 CLAUDE.md/AGENTS.md `Response Style` |
| **lean-code** | `.claude/skills/lean-code/` | LLM 코딩 안티패턴 (참조, 구 karpathy). 실제 강제는 CLAUDE.md/AGENTS.md `Coding Principles` |
| **feature-architecture** | `.claude/skills/feature-architecture/` | feature-first 구조 규율 (참조). 실제 강제는 CLAUDE.md/AGENTS.md `Architecture Principles` |
| **clarity** | `.claude/skills/clarity/` | 요청 모호도 분석 (5차원 스코어링) + PASS 후 접근법 게이트 (2-3 대안 + 추천 1개) |
| **design** | `.claude/skills/design/` | UI/UX 설계 게이트 (토큰+레이아웃+원칙, 반응형) |
| **ctxdb-navigator** | `.claude/skills/ctxdb-navigator/` | 키워드 depth 컨텍스트 최소 로드 (토큰 절약) |
| **security-check** | `.claude/skills/security-check/` | 보안 검증 게이트 (secrets/취약점/설정/PawPad 산출물, 🔴 시 BLOCK) |
| **context-saver** | `.claude/skills/context-saver/` | 세션 작업 .ctxdb/L2 저장 + AGENT SYNC 갱신 |

### 🔀 Workflow Skills (협업/기획)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **handoff** | `.claude/skills/handoff/` | 세션/에이전트 인수인계 (PawPad snapshot + owner transfer) |
| **checkpoint** | `.claude/skills/checkpoint/` | 컨텍스트 60% 롤오버 게이트 (상태 보존) |
| **grill-me** | `.claude/skills/grill-me/` | 계획/설계 스트레스 테스트 (재귀적 질문 + 용어 canonical 좁힘 + 코드 모순 표면화) |
| **to-prd** | `.claude/skills/to-prd/` | 대화 → PRD (`.claude/pawpad/specs/` 저장 + SPEC_READY) |
| **mockup** | `.claude/skills/mockup/` | PRD-tree→단일 HTML 목업 시각화 (lo/hi-fi, Feature ID 태깅 + drift 경고) |
| **review** | `.claude/skills/review/` | 문서형 크로스에이전트/세션 리뷰 라운드트립 (codex exec 보완·저토큰, request 직접검증 체크리스트) |
| **code-delegate** | `.claude/skills/code-delegate/` | 코딩 단계 서브에이전트 위임 (사용자 선택 모델, spec/lane 포인터 전달, 요약 반환 — 부모 컨텍스트·토큰 절감) |
| **viewer-apply** | `.claude/skills/viewer-apply/` | 뷰어 데이터 JSON(src/viewer/*.json)을 읽어 스팩 동기 (남은 항목 spec 생성/갱신, 삭제 항목 제거/아카이브, confirm·비파괴, mockup viewer 모드와 짝) |

---

## 스킬 호출 패턴

### 기본 호출
```
/resume          # 세션 재개 프로토콜
/codemap         # 심볼 탐색
/caveman         # 압축 모드
/clarity         # 모호도 분석
/lean-code       # 원칙 확인
/design          # UI/UX 설계 게이트 (화면 구현 직전)
/security-check  # 보안 검증 게이트 (커밋/핸드오프/완료 직전)
```

### 협업/기획
```
/grill-me        # 설계 스트레스 테스트 (용어 좁힘·코드 모순 표면화 포함)
/to-prd          # 대화 → PRD + SPEC_READY 등록
/checkpoint      # 60% 컨텍스트 정리
/handoff         # 다음 에이전트 인수인계
```

---

## 스킬 체이닝 예시

### 예시 1: 기획 → 구현 (PawPad 흐름3)
```
1. /clarity 30          ← 기획 모호도 확인
2. /grill-me            ← 설계 스트레스 테스트
3. /to-prd              ← PRD를 PawPad specs/ 저장 + lane SPEC_READY 등록
4. (구현 agent) ON START ← SPEC_READY 발견 → spec+lane read → 인수 (state=WIP)
```
주의: SPEC_READY는 snapshot 불필요 → `/handoff` 아님. `/handoff`는 작업 중간에 snapshot이 필요한 인계(토큰 부족 등)에만 사용.

### 예시 2: 코드 작업
```
1. /lean-code           ← 원칙 검증 (요청된 것만)
2. /codemap             ← 영향 파일 위치 확인
3. /caveman             ← 압축 피드백
```

### 예시 3: 토큰 부족 핸드오프
```
1. /checkpoint          ← 60% 도달, lane/codemap 정리
2. /resume              ← _wip.md 상태 갱신
3. /handoff claude      ← 다른 에이전트로 인수 (state=HANDOFF_TO_*)
```

---

상세: 각 `.claude/skills/{skill}/SKILL.md` | 메타: `.codex/config.json` (skills 배열)

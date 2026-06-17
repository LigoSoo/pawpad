# Claude Code <-> Codex 하이브리드 협업

## 개요
같은 프로젝트를 Claude Code와 Codex 에이전트가 나누어 작업.
파일 시스템 기반 상태 공유로 핸드오프 지원.
역할은 상호 교체 가능 (대칭).

**중요**: 본 문서의 /handoff, /checkpoint, "ON START"는 agent instruction.
Claude Code는 .claude/hooks/*, Codex는 .codex/hooks.json이 trust된 경우 일부 절차를 자동 주입한다.
hook 미신뢰/비활성 시 agent가 SKILL.md를 따라 수동으로 파일을 읽고 쓴다.

---

## 역할 분담 (기본값, 교체 가능)

| 에이전트 | 주 역할 | 사용 시기 |
|---------|--------|---------|
| Claude Code | 기획, 설계, 의사결정, 복잡 로직 | 토큰 풍부, 사양 정리 필요 |
| Codex | 구현, 리팩토링, 반복 작업, 테스트 | 코딩 작업, Claude 토큰 부족 시 인수 |

상호 교체 가능. 반대 시나리오(Codex 기획 -> Claude 구현)도 동일 프로토콜.

---

## State Enum (5종 + BLOCKED)

| state | 의미 | 인수 방법 |
|-------|------|----------|
| WIP | 작업 진행 중 | owner만 작업 |
| SPEC_READY | 기획 완료, 구현 대기 | 구현 agent가 spec read, state=WIP, owner=본인 |
| HANDOFF_TO_CODEX | Codex 인수 요청 | Codex가 snapshot read, state=WIP, owner=Codex |
| HANDOFF_TO_CLAUDE | Claude 인수 요청 | Claude가 snapshot read, state=WIP, owner=Claude |
| HANDOFF_TO_NEXT_AGENT | 다음 agent 미정 | 인수 agent가 snapshot read, state=WIP, owner=본인 |
| BLOCKED | 외부 차단 | owner가 차단 해소 시 state=WIP 복귀 |

---

## 작업 흐름

### 흐름 1: Mid-task 핸드오프 (토큰/context 부족)

1. Context 50-60% 도달 추정 -> agent가 /checkpoint 절차 수행
2. lane 파일 (.claude/pawpad/wip/{feature}.md) 갱신
3. codemap/_index.md 갱신 (신규 심볼)
4. agent가 /handoff {to-agent} {feature} {reason} 절차 수행:
   - snapshot 작성: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md
   - _wip.md Active Lanes에 state=HANDOFF_TO_* + handoff 필드 추가
5. _meta.md RECENT에 1줄 추가
6. 다음 에이전트 세션 시작 -> ON START에서 _wip.md state/handoff 필드로 snapshot 위치 파악
7. 인수: state=WIP, owner=받는 agent로 변경 (handoff 필드 제거)

### 흐름 2: 병렬 기능 분담

- Feature A: .claude/pawpad/wip/feature-a.md (owner: Claude Code, state: WIP)
- Feature B: .claude/pawpad/wip/feature-b.md (owner: Codex, state: WIP)
- _wip.md Active Lanes에 둘 다 등록
- _wip.md Locks 섹션에 파일 경로 매핑:
  - src/moduleA/** -> Claude Code
  - src/moduleB/** -> Codex
- 각자 lane 파일만 수정. 타 에이전트 lane 읽기만 가능.
- codemap/_index.md:
  - 추가: 누구나
  - 수정/삭제: lane owner만

### 흐름 3: 기획 -> 구현 분리 (SPEC_READY)

1. 기획 agent:
   - .claude/pawpad/specs/{feature}.md 작성
   - 아키텍처 결정 있으면 decisions/arch.md ADR 추가
   - lane 파일 생성: state=SPEC_READY, owner=기획 agent
   - _wip.md Active Lanes에 등록
2. 구현 agent:
   - ON START -> _wip.md 확인
   - state=SPEC_READY 발견 -> specs/{feature}.md read
   - 인수: state=WIP, owner=구현 agent로 변경
   - 구현 시작

### 흐름 4: 60% 정리 후 새 세션 재개

1. agent가 /checkpoint 절차 수행
2. lane 파일 + codemap 갱신
3. (필요 시) /handoff 절차 (같은 에이전트면 self-handoff)
4. 새 세션 시작
5. ON START 절차 -> lane 파일 read -> 끊김 없이 이어 작업

### 흐름 5: Codex native adapter

1. Codex 시작 후 /hooks에서 project-local hooks review/trust
2. SessionStart hook:
   - .ctxdb/.state/codex-turn-count reset
   - .ctxdb/.state/codex-loaded reset
3. UserPromptSubmit hook:
   - 사용자 prompt keyword 추출
   - .ctxdb/INDEX.md -> L1<=1 -> L2<=2 로드 (session dedupe: 이미 로드한 ref 재주입 안 함)
   - .claude/codemap/_index.md HOT/keyword match 추가 (codemap.inject 토글 따름)
4. PreCompact hook:
   - native compaction 직전 context-saver 유도 + 중복 가드(codex-last-compact) 기록
5. Stop hook:
   - .ctxdb/.state/codex-turn-count 증가
   - 8턴(최근 compaction 저장 시 생략) 또는 L2 size 초과 시 context-saver continuation 요구
6. hook 미신뢰/비활성 시 기존 수동 ON START/ON STOP 절차 사용

> Claude Code도 동일 구조: .claude/hooks/ SessionStart(state reset) + UserPromptSubmit(ctxdb-inject.ps1 keyword 최소로드) + PreCompact + Stop. 토글은 공통 .claude/pawpad-config.json.

---

## 핸드오프 마크 (3종 + SPEC_READY)

| 마크 | 의미 |
|------|------|
| HANDOFF_TO_CODEX | Claude Code -> Codex |
| HANDOFF_TO_CLAUDE | Codex -> Claude Code |
| HANDOFF_TO_NEXT_AGENT | 다음 에이전트 미정 (일반 마크) |
| SPEC_READY | 기획 산출물 준비, 구현 agent 대기 (handoff 아님, snapshot 불필요) |

마커는 _wip.md Active Lanes의 state 필드에 명시.
snapshot 파일 경로는 같은 lane의 handoff 필드에 기록 (HANDOFF_TO_* 에만 해당).

---

## Context Window 토큰 임계값 (60% 기준)

| 상태 | Context % | agent 액션 |
|------|----------|-----------|
| 정상 | 0-50 | 계속 진행 |
| 체크포인트 | 50-60 | /checkpoint 절차 (lane/codemap 갱신) |
| 핸드오프 | 60-70 | /handoff 절차 (snapshot 작성) |
| 전환권장 | 70-85 | 새 세션 즉시 시작 |
| 임계 | 85+ | 즉시 STOP, 핸드오프 |

자세한 추정 휴리스틱: .claude/skills/checkpoint/SKILL.md

---

## 공유 파일 규칙

### 읽기/쓰기 (lane 규칙 따름)
- .claude/pawpad/_wip.md (router. lane 등록/해제/state 변경/owner 변경만)
- .claude/pawpad/wip/{feature}.md (각자 lane만 수정)
- .claude/pawpad/wip/done/{feature-id}_{timestamp}.md (완료 lane, 이동만, 삭제 금지)
- .claude/pawpad/_meta.md (완료/인수 1줄 추가만)
- .claude/pawpad/handoffs/ (snapshot 추가만)
- .claude/pawpad/specs/ (기획 산출물)
- .claude/codemap/_index.md (추가: 누구나 / 수정·삭제: owner만)
- .claude/pawpad/decisions/ (ADR 추가만)
- .codex/config.toml (Codex project config layer notes)
- .codex/hooks.json (Codex hook router)
- .codex/hooks/ (Codex hook scripts)
- .agents/skills/ (Codex repo skills)
- .claude/pawpad-config.json (codemap inject 토글 등 toolkit 런타임 설정)

### 읽기 전용
- CLAUDE.md / AGENTS.md
- .claude/settings.json (Claude Code hook)
- .codex/config.json (Codex 보조 설정)
- pubspec.yaml (변경 시 _wip.md Locks 명시 필수)

---

## 충돌 방지 규칙

1. 한 lane은 한 에이전트만 수정 (owner 명시).
2. _wip.md (router)는 lane 등록/해제/state/owner 변경만.
3. codemap/_index.md:
   - 추가: 누구나
   - 수정/삭제: lane owner만 (_wip.md Locks 확인)
4. pubspec.yaml 변경 시 _wip.md Locks에 명시 + _meta.md RECENT에 알림.
5. 동시 수정 충돌 시 양쪽 라인 보존 후 다음 세션에서 정리.
6. 완료 lane은 wip/done/{feature-id}_{timestamp}.md로 이동 (삭제 금지, 재작업 시 이전 보존).

---

## Verification Evidence

lane "## Verification Evidence" 섹션은 검증 근거(테스트/분석/리뷰 결과)를 기록한다. 무제한 누적 시 lane 파일이 비대해져 매 세션 ON START 로드 비용이 커지므로 경량 유지한다.

규칙:
1. lane 본문에는 최근 2건만 유지.
2. 검증 근거 추가로 2건을 초과하면, 가장 오래된 항목부터 .claude/pawpad/verifications/{feature-id}-archive.md 상단에 append (newest first) 후 lane에서 제거.
3. lane Verification Evidence 섹션 하단에 포인터 1줄 유지:
   "> 이전 검증 N건 -> .claude/pawpad/verifications/{feature-id}-archive.md"
4. 분석전용/소작업은 본문에 "not applicable: analysis-only"만 기록 (아카이브 불필요).

근거: 후속 세션은 lane의 state·next-steps·최근 검증만 참조하고, 과거 검증 근거는 audit 목적(미사용)이다. 핫패스에서 분리해도 정보 손실 없이 on-demand 복원 가능 (_meta.md RECENT 8줄 + sessions/ 이월과 동일 패턴). archive 파일은 추가만, 기존 내용 수정·삭제 금지(audit).

---

## Completed Task Log

lane의 작업추적 섹션(진행/그룹/Backlog/Next Steps 등)에 쌓이는 완료(✅) 작업항목은 상세 구현노트째 누적되어 세션 재개 시 매번 재read 비용을 키운다. Verification Evidence와 동일하게 경량 유지한다.

규칙:
1. 미완/진행 항목(⏳/⚠/🆕/무마커)은 항상 lane에 전수 유지.
2. 완료(✅) 항목은 "다음 세션 재개 포인트" 날짜(직전 checkpoint) 이후 것만 lane 유지, 그 이전 ✅는 .claude/pawpad/verifications/{feature-id}-tasklog.md 상단에 append (newest first) 후 lane에서 제거.
3. lane 완료 영역 말미에 포인터 1줄 유지:
   "> 완료 작업 M건 -> .claude/pawpad/verifications/{feature-id}-tasklog.md"
4. 이월 시점: ON checkpoint(/checkpoint·60% rollover) 및 ON TASK DONE 직전. handoff는 checkpoint 절차에 포함.

근거: 후속 세션은 미완/진행 + 최근 완료 맥락만 필요하고, 과거 완료 항목은 audit(미사용)이다. lane은 archive 2종을 둔다 — {feature-id}-archive.md(검증근거) + {feature-id}-tasklog.md(완료작업). 둘 다 추가만, 수정·삭제 금지(audit).

---

## Owner Transfer (인수 시 필수)

핸드오프 받는 agent는 작업 시작 전 owner 변경 필수:

1. lane 파일 (.claude/pawpad/wip/{feature}.md):
   - State: HANDOFF_TO_* -> WIP
   - Owner: {송신자} -> {수신자 본인}
2. _wip.md Active Lanes 동기화:
   - state: WIP
   - owner: 수신자
   - handoff: 필드 제거 (인수 완료)
   - updated: 현재 시각
3. _meta.md RECENT에 1줄:
   "YYYY-MM-DD: ACCEPT {feature} by {수신자}"

이 절차 누락 시 소유권 불명 -> 다음 에이전트가 잘못된 owner로 작업할 위험.

---

## 호출 방법

### Claude Code -> Codex
1. agent가 /checkpoint 절차 (60% 도달 시)
2. agent가 /handoff codex {feature} {reason} 절차 수행
   - snapshot 작성 + _wip.md state/handoff 갱신
3. 사용자가 Codex 세션 시작
4. Codex ON START -> HYBRID.md + _wip.md + handoffs/{지정} read
5. Codex가 owner 변경 후 작업 재개

### Codex -> Claude Code
1. agent가 /checkpoint 절차
2. agent가 /handoff claude {feature} {reason} 절차
3. 사용자가 Claude Code 세션 시작
4. Claude Code ON START -> 동일 절차
5. Claude Code가 owner 변경 후 작업 재개

### 자기 자신에게 (세션 전환)
1. agent가 /checkpoint 절차 (저장만, snapshot 없음, owner 유지)
2. 새 세션 시작
3. ON START -> lane 파일 read -> 재개 (owner 그대로)

---

## 주의사항

DO NOT
- 두 에이전트가 동시에 같은 lane 파일 수정 금지
- _wip.md 직접 작업 상세 작성 금지 (router는 메타 정보만)
- codemap/_index.md 기존 항목을 비owner가 수정/삭제 금지
- 완료 lane 삭제 금지 (wip/done/으로 이동, timestamp 명명)
- 같은 feature 재작업 시 done 파일 덮어쓰기 금지 (timestamp로 구분)
- 인수 시 owner 변경 누락 금지
- pubspec.yaml 의존성 충돌 (변경 시 알림)

DO
- 작업 전 ON START 절차 실행
- 작업 후 lane 파일 + codemap + _meta.md 갱신
- 60% 도달 추정 시 /checkpoint -> /handoff
- 핸드오프 시 Next Commands 명확히 작성
- 인수 시 owner를 본인으로 변경 (필수)
- 완료 lane은 wip/done/{feature-id}_{timestamp}.md로 이동

---

## Backup (안전장치)

setup script -Force 실행 시 사용자 작성 데이터 자동 백업:
- 백업 위치: .claude/pawpad/backup/{YYYY-MM-DD_HHmm}/
- 백업 대상:
- **PawPad**: _wip.md, _meta.md, decisions/, wip/ (done 포함), handoffs/, specs/, codemap/_index.md
- **Context files**: CLAUDE.md, AGENTS.md, .claude/HYBRID.md, .claude/settings.json, .codex/config.json, .gitignore, CONTEXT.md, .claude/SKILLS_MANIFEST.md
- **Codex adapter**: .codex/config.toml, .codex/hooks.json, .codex/hooks/, .agents/skills/
  - **Claude hooks/config**: .claude/hooks/, .claude/pawpad-config.json
- .gitignore에 .claude/pawpad/backup/ 자동 등록 (민감 정보 보호)
- 복구 필요 시 백업 디렉토리에서 수동 복원

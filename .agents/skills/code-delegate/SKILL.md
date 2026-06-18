---
name: code-delegate
description: Coding-phase subagent delegation gate. Use when moving from design to coding to spawn a coding subagent on a user-chosen model, passing the written spec/lane by pointer, so the parent (Opus) context stays lean and token cost drops. Subagent returns a concise summary for parent feedback.
---
# DO NOT EDIT: generated from .claude/skills/code-delegate/SKILL.md by pawpad-setup.ps1.
# Code-Delegate Skill - 코딩 서브에이전트 위임 게이트

## 목적
기획·구조 설계는 상위 에이전트(고추론·대용량 컨텍스트, 예: Opus 4.8)로 진행하고, 코딩은 사용자가 고른 모델의 서브에이전트에 위임한다. 코딩 반복이 서브에이전트의 독립 context에서 일어나 부모 컨텍스트는 린하게 유지되고 토큰 비용도 준다.

## 핵심 원리 (왜 절감되나)
- 서브에이전트는 독립 context window. 부모는 (전달 프롬프트 + 서브의 최종 메시지)만 흡수한다. 파일 read/write와 도구 호출 수십 회는 전부 서브 context에 격리된다.
- 모델 선택: 복잡 코딩은 상위 모델, 단순·반복 코딩은 하위 모델(Sonnet/Haiku)로 토큰·컨텍스트 절약.
- 효과: 부모가 30%선을 유지 → 코딩으로 60%까지 치솟는 것 방지 → checkpoint/handoff 빈도 감소.

## 트리거
/code-delegate [모델]  또는 구현 경계 자동제안
- 자동제안: 설계 완료 후 코딩 전환 경계(SPEC_READY 또는 written 설계 직후)에서 1회 위임 제안(강제 X). 거절 시 인라인 코딩.
- 수동: /code-delegate (모델 미지정 시 선택지 제공).

## 위임 적합성 게이트 (선행 판정)
아래 충족 시에만 위임 권장:
1. written 설계 존재 — 구현 계획이 spec(.claude/pawpad/specs/{feature}.md) 또는 lane에 적혀 있다. 대화에만 있으면 dump 필요 -> 이점 반감(경고).
2. 코딩 단계 — 기획/구조 결정 완료, 실제 파일 변경 단계.
3. 격리 가능 — 부모와 잦은 상호작용이 불필요한 독립 범위.
미충족 시(설계 미작성/탐색 단계/고도 상호작용) 위임 비권장, 인라인 진행 안내.

## 실행 절차 (Claude Code 주력)
1. 위임 적합성 게이트 판정. 부적합이면 사유 + 인라인 권장.
2. 모델 선택 — AskUserQuestion(체크박스), 작업 복잡도 기준 추천 1개 first:
   - 복잡/대규모 -> opus (추천 예시), 일반 코딩 -> sonnet, 단순/반복 -> haiku
   - 추천 1개 표시 + 근거(복잡도). 선택지 규칙은 CLAUDE.md 준수.
3. 서브에이전트 spawn — Agent 도구:
   - model = 선택 모델
   - 프롬프트 = (a) spec/lane/codemap 포인터 read 지시(경로 명시, 본문 dump 아님) + (b) 작업 범위·완료기준 + (c) 반환 형식 지시(4번)
4. 반환 형식 (서브에이전트에 명시) — 부모 린 유지:
   - 변경 파일 경로 목록
   - 핵심 구현 결정 요약
   - 검증 상태(analyze/test/security 결과)
   - 전체 코드 dump 금지. 부모가 필요 시 특정 파일만 요청.
5. 피드백 루프 — 결과 검토 후 수정 필요 시: SendMessage로 같은 서브 이어가기(context 유지) 또는 피드백 포함 신규 dispatch.
6. lane/DoD는 부모 소유 — 서브는 코딩만. lane 갱신·codemap·_meta·완료 판정은 부모가 한다.

## 런타임
- Claude Code (주력): Agent(Task) 도구 model 오버라이드 지원(opus/sonnet/haiku/fable). 위 절차 그대로.
- Codex (폴백): per-call 모델 선택 메커니즘이 달라 자동 모델-핀 미보장. 대안 안내 — 사용자가 원하는 모델로 별도 Codex 세션을 띄우고 spec/lane read 후 코딩. 스킬은 이 안내만 제공.

## 비용/컨텍스트 메모
- 컨텍스트 절감은 과금 방식과 무관하게 확실(서브 격리).
- 토큰 비용: API 과금이면 달러 직접 절감, 구독(Pro/Max)이면 rate-limit 여유로 환산.
- 한계: 부모는 매 반환을 흡수하므로 다회 피드백이면 부모도 누적 증가(단 코딩 본체가 격리되어 여전히 이득). 반환 요약 유지가 핵심.

## 기존 스킬과 관계
- handoff = 작업 인계(owner 이전, 다른 에이전트/세션). code-delegate = 부모 유지 + 코딩만 서브 위임(owner 불변). 별개.
- to-prd/SPEC_READY = 위임 전제(written 설계) 공급원.
- 목적은 checkpoint/handoff 빈도 감소.


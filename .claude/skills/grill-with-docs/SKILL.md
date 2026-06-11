---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates project documentation (glossary + PawPad ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against the project's language and documented decisions.
---

## What to Do

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Domain awareness

During codebase exploration, also look for existing documentation.

### 문서 위치 (이 프로젝트 / PawPad 규약)

- 용어집(glossary): `CONTEXT.md` (프로젝트 루트). 없으면 첫 용어 확정 시 생성.
- 아키텍처 결정(ADR): `.claude/pawpad/decisions/arch.md` (append, ADR-NNN 형식).
- 거부된 접근: `.claude/pawpad/decisions/rejected.md`
- 기능 spec: `.claude/pawpad/specs/{feature-id}.md`

주의: Matt Pocock 원본의 `docs/adr/`, `CONTEXT-MAP.md` 다중 컨텍스트 구조는 이 프로젝트에서 쓰지 않는다. ADR은 PawPad `decisions/arch.md` 단일 위치로 통일.

## During the session

### Challenge against the glossary

용어가 `CONTEXT.md` 기존 정의와 충돌하면 즉시 지적한다. "용어집은 '취소'를 X로 정의했는데 지금 Y를 의미하는 것 같다 — 어느 쪽인가?"

### Sharpen fuzzy language

모호하거나 중의적인 용어 → 정확한 canonical 용어 제안. "'account'라고 했는데 Customer인가 User인가? 둘은 다른 개념이다."

### Discuss concrete scenarios

도메인 관계를 논의할 때 구체 시나리오로 stress-test 한다. 엣지 케이스를 만들어 개념 경계를 명확히 하도록 강제한다.

### Cross-reference with code

사용자가 동작을 설명하면 코드와 일치하는지 확인한다. 모순 발견 시 표면화: "코드는 Order 전체를 취소하는데 방금 부분 취소가 가능하다고 했다 — 어느 게 맞나?"

### Update CONTEXT.md inline

용어가 확정되면 즉시 `CONTEXT.md`를 갱신한다. 모아두지 말고 그때그때 기록한다.

`CONTEXT.md`는 구현 세부를 일절 담지 않는다. spec, 스크래치패드, 구현 결정 저장소로 쓰지 말 것. 용어집(glossary)일 뿐이다.

### Offer ADRs sparingly

다음 세 가지가 모두 참일 때만 ADR을 제안한다:

1. **되돌리기 어려움** — 나중에 바꾸는 비용이 큼
2. **맥락 없이는 의외** — 미래 독자가 "왜 이렇게 했지?" 의문을 가짐
3. **실제 트레이드오프 결과** — 진짜 대안이 있었고 특정 이유로 선택함

하나라도 빠지면 ADR을 생략한다. ADR 작성 시 `.claude/pawpad/decisions/arch.md`에 append 한다 (별도 `docs/adr/` 생성 금지).

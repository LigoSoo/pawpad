---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree, sharpening fuzzy terms and surfacing contradictions against the codebase. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# DO NOT EDIT: generated from .claude/skills/grill-me/SKILL.md by pawpad-setup.ps1.
Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead. During exploration also look for existing documentation (specs, PRD, decisions) that bears on the plan.

While grilling, sharpen the conversation:

- Sharpen fuzzy language — 모호하거나 중의적인 용어는 정확한 canonical 용어로 좁힌다. "'account'라고 했는데 Customer인가 User인가? 둘은 다른 개념이다."
- Discuss concrete scenarios — 도메인 관계나 경계가 걸리면 구체 시나리오·엣지 케이스로 stress-test 해 개념 경계를 강제로 드러낸다.
- Cross-reference with code — 사용자가 동작을 설명하면 코드와 일치하는지 확인하고, 모순을 즉시 표면화한다. "코드는 Order 전체를 취소하는데 방금 부분 취소가 가능하다고 했다 — 어느 게 맞나?"


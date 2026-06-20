---
name: to-prd
description: Turn the current conversation context into a PRD, save it to the PawPad specs folder, and mark the lane SPEC_READY for the implementation agent. Use when user wants to create a PRD from the current context.
---

# DO NOT EDIT: generated from .claude/skills/to-prd/SKILL.md by pawpad-setup.ps1.
This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary (`CONTEXT.md`) vocabulary throughout the PRD, and respect any ADRs in `.claude/pawpad/decisions/arch.md` for the area you're touching.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

3. Write the PRD using the template below, then save it to `.claude/pawpad/specs/{feature-id}.md`.

4. Register the lane for the hybrid handoff flow (SPEC_READY는 snapshot 불필요 — `/handoff` 쓰지 말 것):
   - **lane 파일 생성**: `.claude/pawpad/wip/{feature-id}.md`
     - Owner: 기획 agent / State: SPEC_READY / spec 경로: `.claude/pawpad/specs/{feature-id}.md` / 다음 단계 / updated
     - 기존 lane 있으면 새로 만들지 말고 갱신 (중복 생성 금지)
   - `.claude/pawpad/_wip.md` Active Lanes에 등록: state=SPEC_READY, owner=기획 agent, lane 경로
   - `.claude/pawpad/_meta.md` RECENT에 1줄 추가: "YYYY-MM-DD: SPEC_READY {feature-id}. spec 작성 완료. [agent]"
   - 구현 agent가 ON START에서 SPEC_READY 발견 → spec + lane read → 인수 (state=WIP, owner=본인). resume skill 참조. snapshot 불필요하므로 `/handoff` 아님.

주의: 외부 이슈 트래커 발행, `ready-for-agent` 라벨, `/setup-matt-pocock-skills` 셋업은 이 프로젝트에서 쓰지 않는다. PRD는 PawPad `specs/` + `SPEC_READY` state로 인계한다.

## PRD Template

```markdown
## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

Example:
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.
```


---
name: karpathy
description: LLM coding anti-pattern reference. Enforcement lives in CLAUDE.md/AGENTS.md Coding Principles; this file is the detailed checklist. No separate invocation needed.
---
# Karpathy Principles - LLM Coding Anti-patterns (참조 문서)

> **강등 안내**: 코딩 원칙은 **CLAUDE.md/AGENTS.md `Coding Principles (Karpathy)`가 강제**한다.
> 이 파일은 별도 호출 대상이 아니라 **상세 체크리스트 참조**용이다.

## 4 Core Rules

### 1. DO NOT OVER-ENGINEER
요청한 것만. 그 이상 없음.
- 추가 기능/추상화/유연성 임의 도입 금지
- "시니어가 과하다고 할까?" -> 단순화

### 2. DO NOT CHANGE WHAT IS NOT ASKED
명시된 파일/함수만.
- 인접 코드 주석 포맷 임의 개선 금지
- 기존 스타일 그대로
- 기존 데드 코드 -> 언급만, 삭제 금지
- 테스트: 변경된 모든 줄이 요청에 직접 연결되는가.

### 3. VERIFY BEFORE IMPLEMENTING
구현 전 먼저 파악.
- 기존 코드 패턴/의존성 먼저 읽기
- .claude/codemap/_index.md로 관련 파일 위치 먼저 확인
- 가정으로 시작하지 않음

### 4. CONFIRM SCOPE WHEN UNCERTAIN
불명확하면 구현 전 질문.
- 범위 불명확 -> 추측 금지
- 여러 해석 가능 -> 선택지 제시

## Orphan Cleanup
내 변경으로 생긴 미사용 항목 -> 제거. 기존 데드 코드 -> 언급만.

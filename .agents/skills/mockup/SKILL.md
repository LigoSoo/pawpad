---
name: mockup
description: PRD-tree를 단일 HTML 목업으로 투영하는 기획 시각화 게이트. 기능이 어느 메뉴/화면에 위치하는지 코딩 전에 시각 확인하고, Feature ID로 PRD-tree와 동기 상태를 추적(drift 경고)한다. 와이어프레임(lo-fi)/디자인반영(hi-fi) 선택. PRD/PRD-tree 갱신 후 또는 사용자가 "목업"/"mockup"/"화면 시안"을 언급할 때 사용.
---

# DO NOT EDIT: generated from .claude/skills/mockup/SKILL.md by pawpad-setup.ps1.
# Mockup Skill - 기획 목업 게이트 (단일 HTML)

## 목적
기획 단계 산출물(PRD-tree)을 **단일 HTML 목업**으로 투영한다.
- "지금 어떤 기능이 기획됐고, 어느 메뉴/화면에 위치하는지"를 코딩 전에 시각 확인 → 기획 단계에서 수정 → 코딩 재작업 방지.
- 비개발자도 브라우저로 바로 확인(전달 가능).
- 각 화면을 Feature ID로 태깅해 PRD-tree와 동기 상태 추적.

clarity/design과의 관계:
- clarity : 요청 모호도(기능 정의) 게이트.
- design  : 토큰/레이아웃/원칙 게이트 (hi-fi 목업은 design 토큰 재사용).
- mockup  : PRD-tree → 화면 구조 시각 투영 + 트리 동기 게이트.

## 성격
Instruction skill. PowerShell command 아님. agent가 절차를 따라 HTML을 생성한다.

## 트리거
/mockup [화면|all] [lo|hi]
- 인자 생략 시: 전체(all) + lo-fi.
- 예: /mockup all lo      -> 전체 화면 와이어프레임
- 예: /mockup TQ-HOME hi  -> 홈 영역 디자인반영 목업
- fidelity 인자 생략 시 기본 lo-fi.

## 산출물
- 위치: `src/mockups/{feature-id}-mockup.html` (PRD/PRD-tree와 같은 src/ 아래 응집)
- 형식: 단일 HTML. 화면당 섹션 + 화면 간 앵커 클릭 이동.
- 단일 fidelity/파일 (lo·hi 동시 내장 토글 금지 — 동기 부담).

## fidelity 2단계

### lo-fi (와이어프레임, 기본)
- 회색 박스 + 라벨 + Feature ID만. 색/이미지/실 타이포 없음.
- 목적: 초기 반복에서 구조·배치·메뉴 위치만 빠르게 검토(재생성 싸게).
- 구조(PRD-tree)가 안정화되면 hi-fi 전환을 **자동 제안**(CLAUDE.md 단계경계 규칙).

### hi-fi (디자인반영)
- design 스킬 토큰(색/타이포/간격) 적용. **신규 토큰 임의 도입 금지** — 누락 시 design 절차로 토큰 추가 제안 후 진행.
- 목적: 구조 확정 후 실제 룩앤필 확인.

## Feature ID 태깅 (필수)
- 모든 목업 화면에 대응 Feature ID 라벨 부착 (예: 화면 헤더에 `TQ-HOME-01`).
- 화면이 속한 메뉴/내비 위치를 시각적으로 표현(탭바/사이드 등 PRD-tree 계층 반영).

## 동기화 = 단방향 (PRD-tree = source of truth)
- PRD-tree가 단일 진실원. 목업은 트리의 시각 투영.
- 기획 변경은 **PRD-tree(인덱스) + 해당 src/prd/{area}.md를 먼저 수정**하고 목업 재생성. 코드+문서 원자적 갱신 규율 준수.
- 목업에서 직접 고친 내용을 트리로 역반영하지 않음(SoT 이원화 금지).

## drift 검사 (생성 시마다 필수)
PRD-tree leaf의 Feature ID 집합 ↔ 목업 화면 ID 집합을 비교해 출력:
```
drift 검사: {일치 N개}
- 누락 (트리에 있으나 목업에 없음): {ID 목록 또는 없음}
- 고아 (목업에 있으나 트리에 없음): {ID 목록 또는 없음}
```
- 누락/고아가 있으면 사용자에게 알리고, 기획 불일치인지 목업 갱신 필요인지 확인.
- (*) 표시된 후속 기능 ID는 누락 경고에서 제외(트리 규칙 따름).

## 절차
1. PRD-tree.md read → leaf Feature ID + 메뉴 계층 추출.
2. 대상 화면 결정(인자 [화면|all]) + fidelity 결정(인자 [lo|hi], 기본 lo).
3. hi-fi면 design 토큰 소스 확인(없으면 lo-fi 권고 또는 토큰 제안).
4. 단일 HTML 생성 → `src/mockups/{feature-id}-mockup.html`. 화면별 Feature ID 라벨 + 메뉴 위치 표현.
5. drift 검사 출력.
6. lo-fi이고 구조 안정화 판단 시 hi-fi 전환 제안(1회).

## 선택지 질문 규칙
대상 화면·fidelity 등 선택지가 있는 질문은 **AskUserQuestion(체크박스)** 로 받는다. 자유서술·수치 입력은 텍스트.

## 원칙
- 정적 화면 투영만. 실제 클릭 로직/상태/인터랙션 비범위(화면 간 앵커 이동만).
- lean-code 적용: 요청 화면만, 과한 연출 금지.
- 신규 디자인 토큰 임의 정의 금지(design 절차 경유).
- 산출물은 기획물 → 코드 아님. 구현은 별도 단계.


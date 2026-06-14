---
name: design
description: Framework-neutral UI/UX design gate. Use before or while building a screen/component to lock design-system tokens, structure the responsive component layout, and review against core UI principles. Use when user mentions UI, layout, screen design, or "design this".
---

# DO NOT EDIT: generated from .claude/skills/design/SKILL.md by pawpad-setup.ps1.
# Design Gate Skill - UI/UX 설계 게이트 (프레임워크 중립)

## 목적
화면/컴포넌트 구현 전·중에 한 번에:
(1) 디자인 시스템 토큰 고정, (2) 반응형 레이아웃 구조 설계, (3) UI 원칙 검토.
clarity가 "무엇을 만드나"를 좁힌다면, design은 "어떻게 보이고 배치되나"를 좁힌다.
프레임워크(Flutter/React/Vue/네이티브/웹 등)는 프로젝트의 것을 따른다 — 이 스킬은 도구 중립.

## 성격
Instruction skill. PowerShell command 아님. 에이전트가 절차를 따라 설계안을 출력.

## 트리거
/design [화면/컴포넌트 설명]
- 예: /design 로그인 화면
- 예: /design 회원 목록 카드

## 3단계 (순차)

### 1단계 — 디자인 시스템 토큰 확인
구현 전 토큰 소스 확인/고정 (하드코딩 금지):
- 색상: 프로젝트 색상 토큰/팔레트 (raw hex 하드코딩 금지)
- 문자열: 문자열/i18n 리소스 (하드코딩 금지)
- 간격: 스페이싱 스케일 (4 / 8 / 12 / 16 / 24 / 32)
- 타이포: 텍스트 스타일 토큰 (theme / 타이포 스케일)
- 컴포넌트: 기존 공용 컴포넌트 재사용 우선 (codemap/_index.md 확인)
누락 토큰 발견 시 → 임의 하드코딩 말고 **토큰 추가 제안** 후 진행.

### 2단계 — 레이아웃 구조 설계
- 컴포넌트 트리 스케치: 루트 컨테이너 > 헤더/본문 > 핵심 컴포넌트 계층
- 반응형: breakpoint(mobile < 600 / tablet 600-1024 / desktop > 1024), 뷰포트/컨테이너 쿼리 필요 여부
- 상태 연결: 프로젝트 상태관리(store/provider/hook) 연결점 (codemap 참조, read/write 구분)
- 출력: 컴포넌트 트리 + 각 노드 책임 한 줄

### 3단계 — UI 원칙 체크 (6항목)
| 원칙 | 확인 |
|------|------|
| 시각 위계 | 주요 액션/정보가 크기·색·위치로 우선 표현되나 |
| 여백·정렬 | 스페이싱 스케일 일관, 정렬 그리드 준수 |
| 대비·가독성 | 텍스트 대비 WCAG AA(4.5:1) 충족 |
| 접근성 | 터치 타깃 충분(>=44~48px), 접근성 라벨, 폰트 스케일 대응 |
| 일관성 | 기존 화면 패턴과 일치, 컴포넌트 재사용 |
| 상태 표현 | 로딩 / 빈 / 에러 / 성공 4상태 모두 다룸 |

## 출력 포맷
```
디자인 계획: {화면명}
1. 토큰   : 색상/간격/타이포 [사용 토큰], [추가 제안]
2. 컴포넌트트리: 루트 > ... (계층 + 책임)
3. 반응형 : [breakpoint별 레이아웃 변화]
4. 원칙체크: 시각위계 ✓ / 여백 ✓ / 대비 ⚠ / 접근성 ✓ / 일관성 ✓ / 상태 ⚠
5. 미해결 : [확인 필요 항목]
```

## 원칙
- 새 색상/간격/타이포 임의 도입 금지 → 토큰 추가는 명시적 제안 후.
- 기존 공용 컴포넌트 재사용 우선 (codemap/_index.md 확인).
- 4상태(로딩/빈/에러/성공) 누락 금지.
- lean-code 적용: 요청된 화면만, 과한 애니메이션/추상화 금지.
- 모든 플랫폼 공통: 반응형 breakpoint 명시. 고정 px 레이아웃 지양.

## 후속 산출물 / PawPad 등록
design 통과 후 spec 필요 시 **to-prd와 동일한 PawPad 등록 절차** 따름 (specs 작성 + lane SPEC_READY + _wip/_meta 등록 + 구현 agent 인수). 상세: to-prd skill. spec에 디자인 계획 포함. SPEC_READY는 snapshot 불필요(`/handoff` 아님).
- _meta.md RECENT 예시(design 맥락): "YYYY-MM-DD: SPEC_READY {feature-id}. 디자인 계획 작성 완료. [agent]"

### 디자인 ADR 기준
- per-screen 배치 결정 → spec에만 기록 (ADR 아님)
- 장기 디자인 시스템 결정(새 token / breakpoint / 재사용 공용 컴포넌트 / navigation pattern)만 `.claude/pawpad/decisions/arch.md`에 append

## clarity / grill 과의 관계
- clarity : 요청 모호도(기능 정의) 게이트 — design 앞 단계.
- grill-me : 설계 의사결정 심문 — 큰 화면/플로우 설계 시 병행.
- design  : 시각·레이아웃·토큰 게이트 — 화면 구현 직전.


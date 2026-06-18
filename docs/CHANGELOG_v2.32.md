# CHANGELOG v2.32 — clarity 접근법 게이트 (brainstorming "2-3 대안 제시" 이식)

> superpowers `brainstorming` 스킬의 "2-3 접근법 제시 + 추천" 메커니즘을 pawpad `clarity`에 이식. brainstorming 통째 도입(specs/writing-plans 경로 이원화)이 아니라 **메커니즘만 차용** — PawPad 생태계(specs/lane/codemap) 무충돌.

## 배경
clarity는 모호도(정보 충분성)를 정량 게이트로 수렴시키지만, **구현 경로가 갈리는 분기**(스택/스키마/아키텍처/핵심 UX)는 단일 계획으로 직행했다. 모호도가 낮아도 복수 정답이 공존하는 설계 선택은 사용자 판단이 필요. brainstorming은 이를 "2-3 접근법 + 추천" 대화로 해소하나, 단순 작업에도 대안을 강제하고 superpowers specs/writing-plans 경로로 빠져 PawPad 흐름과 어긋난다.

## 변경: 접근법 게이트 (clarity 2단 게이트화)
모호도 PASS 직후 **접근법 게이트** 신설. clarity가 정량(모호도=정보 충분성) + 정성(접근법=경로 선택)의 2단 구조가 된다.

### 흐름
```
... 모호도 채점 → PASS (<= 임계값)
   → [접근법 판정]
       ├ 실질 대안 ≥2 → 2-3 접근법(트레이드오프 + 추천 1개) 출력 → AskUserQuestion 선택 → 구현계획
       └ 자명 단일      → 구현계획 직행 (게이트 생략)
```

### 규칙 (대안 제시 원칙 — 추천 필수)
- 대안 2-3개만. 4개 이상 금지(분석마비 방지).
- **추천 정확히 1개 필수**. 0개·복수 금지. 추천 항목 첫 배치 + "(추천)" 라벨 + 근거 1줄 의무.
- 각 대안 트레이드오프 1줄 이상(장점/단점 양면).
- **가짜 대안 금지**: 실질 차이 없거나 자명 단일이면 게이트 생략, 단일 계획 직행(lean-code 정신).
- 대안 판정 기준: 비가역·트레이드오프 갈림 분기만(스택/스키마/아키텍처/핵심 UX). 사소한 명명·포맷 제외.
- 선택지 질문 = AskUserQuestion(체크박스) (CLAUDE.md 선택지 규칙 준수).

### brainstorming 대비 차이 (의도)
- brainstorming = 모놀리식 게이트(질문+대안+설계+writing-plans 전이, HARD-GATE). clarity 이식본 = clarity 정량 게이트에 정성 분기만 가산, lean 가드로 가짜 대안 억제.
- 산출물 경로 불변: clarity는 구현계획(인라인), specs/writing-plans 미연동 → PawPad to-prd/lane/codemap 생태계 무충돌.

## 배포 표면 동기 (live==embed==.agents 미러)
- `.claude/skills/clarity/SKILL.md` (live): 접근법 대안 블록 + 통과 블록 선택접근법 줄 + 실행흐름 5→6단계 + "대안 제시 원칙(추천 필수)" 섹션.
- `pawpad-setup.ps1` 임베드(clarity 블록): 동일 반영. 헤더/STATUS/$ver 2.31→2.32, 완료메시지 CHANGELOG ref, 매니페스트 clarity 행.
- `.agents/skills/clarity/SKILL.md` (Codex 미러): 동일 반영.
- `SKILLS_MANIFEST.md` clarity 행, `README.md`/`GUIDE.md`/`USAGE.md` clarity 서술 + 버전 + 이력, `.claude/codemap/_index.md` v232Changelog 행.

## 범위 외
- brainstorming 통째 도입(specs/writing-plans 경로). 재질문(BLOCK) 선택지화. 신규 스킬(count 18 유지).

## 검증
PSParser parse-ok / live==embed==.agents 미러(clarity 본문 동일) / stale `v2.31 FROZEN`·`(FROZEN v2.31)` 라이브 grep 0(이력 `> v2.31:`·STATUS `이전:` 제외) / 신규 스킬 0(18 유지) / security 🔴0 — 변경 파일(clarity SKILL·`pawpad-setup.ps1`·docs)에 secret/위험 패턴 grep 0건. setup.ps1 변경은 clarity here-string 콘텐츠 + 버전 문자열 편집뿐(신규 로직·자격증명·exec 경로 무).

## 프로세스
분석(brainstorming vs clarity/grill-me/to-prd 비교) → 설계(접근법 게이트, 추천 1개 필수) → live 반영 → 배포 동기(임베드/미러/버전/docs/changelog) → 검증 → codex exec 자율 리뷰(설치 스크립트 변경 = 배포본 영향) → 동결.

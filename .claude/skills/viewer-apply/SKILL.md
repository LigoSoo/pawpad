---
name: viewer-apply
description: 통합 기획 뷰어(spec-viewer)가 제자리 저장한 데이터 JSON(src/viewer/*.json)을 읽어 설계/스팩에 동기하는 게이트. 남은 항목으로 spec 생성/갱신, 삭제 항목 spec 제거. 사용자가 "뷰어 저장함"/"viewer-apply"/"스팩 동기"를 언급할 때 사용.
---

# Viewer-Apply Skill — 뷰어 데이터 → 스팩 동기

## 목적
범용 뷰어(`.claude/skills/mockup/spec-viewer.html`)가 제자리 저장한 데이터 JSON(`src/viewer/{prd,fts,userflow,wire}.json`)을 읽어 설계/스팩에 반영한다. **JSON에 남은 항목 = 설계/개발 대상**(존재=포함), 삭제된 항목 = 제외. 별도 승인/결정 단계 없음 — 저장된 JSON이 곧 SoT.

(뷰어가 File System Access API로 데이터 파일을 직접 제자리 저장하므로 별도 "결정 캡처·다운로드" 단계가 불필요 — 저장된 JSON이 곧 SoT.)

## 성격
Instruction skill. agent가 JSON read 후 spec/lane 동기. 삭제 반영(spec 제거)은 파괴적 → confirm 게이트.

## 트리거
/viewer-apply [feature-id]
- 사용자 "뷰어 저장함" / "스팩 동기" / "viewer 반영" 시.

## 입력 (고정명, on-demand)
`src/viewer/prd.json` · `fts.json`(기능그룹→스팩) · `userflow.json`(메뉴 계층 트리 `{root,tree:[{id,label,feature?,tab?,children?}]}`) · `wire.json`(화면별 `{frame,components:[{type,...}]}`).
**ON START/resume 자동 로드 금지** — 이 스킬 실행 시점에만 read(기획 강화·context 비대화 방지).

## 동기 절차
1. 4 JSON read. `fts.json`의 스팩 노드 = 설계/개발 단위, `prd.json` = 요구 문단, `userflow`/`wire` = 흐름·화면.
2. **신규/유지 항목** → 대응 `specs/{feature-id}.md` 생성(없으면 TEMPLATE 기반)/갱신. PRD-tree·prd/{area}·flow 정합 갱신.
3. **삭제된 항목**(직전 동기엔 있었으나 현 JSON에 없음) → 대응 spec **제거/아카이브**(물리 rm 금지 → done 이동 또는 status=removed), lane 있으면 done 이동. **confirm 게이트**(CLAUDE Escalation: DELETE→STOP).
4. **status(예정/진행중/완료)**는 개발 진행 표시 — agent가 구현하며 해당 JSON 항목 status 갱신(사용자 편집 X). 뷰어 재로드로 가시.
5. 변경 = 코드+문서 원자 단위(Doc Update Rules). lane `## Verification Evidence` 기록(DoD#7).

## 원칙
- **존재=대상, 삭제=제외** (승인 단계 없음).
- 삭제 반영 **비파괴**(done 이동/아카이브) + confirm.
- `src/viewer/*.json` context 자동로드 금지.
- status는 agent가 개발 진행 따라 JSON 갱신 → 뷰어 가시(사용자 불수정).

## 관계
- spec-viewer.html(범용 뷰어, 사용자 편집·제자리 저장) ↔ viewer-apply(저장 JSON → 스팩 동기). 짝.
- mockup viewer 모드(데이터 JSON 생성/갱신) → 사용자 뷰어 편집·저장 → viewer-apply(스팩 동기).
- to-prd(PRD→specs 초기 생성)와 보완: viewer-apply는 뷰어 편집분을 스팩에 반영.

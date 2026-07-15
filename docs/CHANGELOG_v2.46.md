# CHANGELOG v2.46 — design 스킬 시각 품질 재설계 (스킬 21 불변)

Date: 2026-07-15
Base: v2.45 (FROZEN)
Lane: `design-skill-audit`
Source spec: 외부 조사 사양서 v2 (Claude 챗봇 — Anthropic frontend-design/skill-creator + 커뮤니티 상위 스킬 근거)

## Summary

기존 `design` 스킬(절차 게이트: 토큰 확인 + 레이아웃 + UI 원칙 6항목)을 **시각 품질 게이트로 재설계**. 사용자 의도(목업/웹/앱 결과물의 시각적 디자인 설계 스킬)와 기존 스킬 성격(구조 게이트, 미적 품질 규칙 부재) 간 갭을 외부 사양서 콘텐츠 흡수로 해소. 스킬 수 21 불변(신설 아님 — 중복/경계 관리 비용 회피, AskUserQuestion으로 사용자 확정).

핵심 프레임: **"AI 티"는 화려함이 아니라 불일치에서 온다** — 간격 임의값 혼재·radius 혼용·컨트롤 높이 제각각이 아마추어/AI 결과물로 읽히게 한다. 일관성을 1순위 품질 지표로 승격하고 정량 검증 가능하게 만듦.

사양서 구조는 pawpad에 그대로 이식 불가(부적합 6건: 기존 design 중복 / references 12파일×3표면 폭발 / pushy 트리거의 자동제안 규율 충돌 / Python 스크립트 의존 / `/mnt/skills` 챗봇 경로 / 금지 폰트 절대칙) → **단일 SKILL.md lean 재설계로 콘텐츠만 흡수**.

## Added (design SKILL.md 신규 섹션 — live + setup 임베드 + `.agents` 미러)

- **최상위 3원칙**: ①Consistency First(모양·크기·간격은 스케일 토큰에서만 파생, 임의값 금지) ②Intentional Direction(코드 전 방향 명시 선택+사유) ③Anti-slop(제네릭 기본값·과용 폰트·불일치 차단).
- **2-pass 워크플로우**: 계획(방향+토큰 시스템) → 자기비평(브리프 대조·스케일 과다/제네릭 겹침 수정) → 구현(토큰 파생만) → 재비평(정렬·간격·radius·높이 우선 점검 + 품질 플로어).
- **신규 프로젝트 토큰 부트스트랩**: 토큰 없는 프로젝트에 초안 제안 — spacing scale(4px 베이스), 컨트롤 높이(sm32/md40/lg48), radius scale, shadow elevation(e1~e3), 색상 4~6 named hex(neutral+accent 1), 타입 스케일(1.25 모듈러), 시그니처 1개. (기존 스킬은 "토큰 추가 제안"만 있고 초기 시스템 설계 가이드 부재)
- **일관성 시스템 5축 표(★)**: 간격(단일 spacing scale·임의값 금지·수직 리듬) / 크기(컨트롤 높이 위계 동일·아이콘 16/20/24·모듈러 타입·터치 44px) / 모양(radius 단일 체계·border 1값·elevation 단계·아이콘 스타일 통일) / 정렬(그리드·gutter·반복 요소 동일) / 상태(컴포넌트 동일 모양·인터랙션 상태 동일 규칙·transition 150~300ms). + **Token-first**: 전 값 토큰 정의 후 raw 값 작성 금지.
- **anti-slop 체크**: 불일치=AI 티 최우선 정규화 / 과용 폰트(Inter/Roboto/Arial/Space Grotesk) 회피는 **신규 선택 시 한정**(기존 프로젝트 채택 폰트는 토큰 우선으로 존중 — 사양서 절대칙을 pawpad 토큰 원칙과 정합하게 완화) / 경계 기본값 3종(크림+테라코타 serif·near-black+acid·broadsheet) 브리프 명시 없으면 회피 / 금지 패턴(서사 없는 캐러셀·제네릭 SaaS 카드 그리드·가짜 numbered marker·이모지 아이콘·목적 없는 그라디언트/보라 남발).
- **정량 체크(assertion)**: spacing 임의값 0건 / radius 고유값 <=4 / 같은 위계 컨트롤 높이 고유값 <=3 / 폰트 크기 타입 스케일 파생 / shadow elevation 토큰 외 0건.
- **선택지 질문 규칙 섹션**: AskUserQuestion 체크박스 + 추천 1개 "(추천)" 첫 배치 + **옵션 최대 3개**(Codex 질문 도구 계약, v2.45 교훈) — 진단 갭 G3 해소.
- **트리거에 자동 진입 명시**: 외부 문서 구현 진입 게이트(UI/화면 포함 문서 시 1회 추천, v2.44)와 mockup hi-fi 토큰 재사용 연결 — 진단 갭 G2 해소.
- **파이프라인 관계 4자 확장**: 기존 "clarity / grill 과의 관계" → brainstorming(v2.45)/clarity/grill-me/design/mockup 5행. design→mockup 역참조 0이던 갭(G1) 해소.
- **비교 검증**(Before/After, 구현 전 사용자 확인): 동일 대시보드를 Before(불일치 재현: 간격 12종·radius 11종·컨트롤 높이 5종·폰트 10종·그림자 6종·아이콘 혼용) vs After(토큰 파생: 토큰 블록 정의 후 raw design 값 0건, 컨트롤 44px 터치 타깃·상태 4종·focus ring 포함)로 렌더 + 검출 리포트 + 정량 비교표(측정 범위 명시, CSS 직접 추출). 구현 전 사용자 검증 완료.

## Changed

- `.claude/skills/design/SKILL.md`: 전면 재설계. frontmatter description에 visual consistency/anti-slop/quantitative checks 트리거 어휘 추가(자동제안 규율 준수 수준 — pushy 트리거는 미채택). 기존 유지: 성격/도구 중립/레이아웃 설계/UI 원칙 6항목/4상태 의무/PawPad 등록·ADR 기준/lean-code. ADR 기준에 `scale` 추가.
- `pawpad-setup.ps1` (v2.45 → **v2.46**): 헤더 STATUS + `$ver` + design 임베드 블록 교체(literal `@'...'@` 유지, escape 불요) + 완료 요약 ko/en v2.46 bullet.
- `.agents/skills/design/SKILL.md`: setup writer 로직(frontmatter+DO NOT EDIT 헤더+body+CRLF) PowerShell 재생성으로 byte-exact 동기.
- `.claude/codemap/_index.md`: designSkill 항목 신규(G4 해소 — mockup/brainstorming/clarity는 있었으나 design 부재) + HOT 스왑(mockup→design) + setupScript v2.46 + skillsManifest desc 20→21 보정(G5) + v246Changelog·designCompareDemo 항목.
- `README.md` / `GUIDE.md` / `USAGE.md` / `PAWPAD_VERSIONS.md`: 버전·이력·링크 동기(아래 Verification).

## Not changed (스코프 방어)

- 스킬 수 21 / 번들 구성($bpMap ui = design, mockup) / stepTotal / CLAUDE·AGENTS 본문·$tmpl(라우팅 문구 "design(토큰/레이아웃 게이트)" 유효 유지) / SKILLS_MANIFEST(행 설명 유효) / config skills 배열.
- 사양서의 scripts(consistency_audit.py)·검색 DB·references 분리 구조·`.skill` 패키징 — 미채택(pawpad 무의존·단일 파일·setup 배포 철학).

## Verification

- PSParser tokenize: parse errors 0.
- live SKILL.md == setup 임베드(+CRLF) == `.agents` 미러(-헤더): PowerShell byte 대조 3항 모두 True. 미러 EOF 0d0a0d0a.
- setup 전체 bare-LF 0 (CRLF 오염 없음), BOM 유지.
- 진단 갭 G1~G5 전항 해소 확인.
- stale grep: `v2.45`(이력 제외)·구 섹션명(`clarity / grill 과의 관계`) 라이브 0.
- security-check: 텍스트/instruction + 데모 HTML(정적, 스크립트 0) — secrets 0.
- fresh install smoke: 샌드박스 full 97c/0f exit 0(스킬 21·미러 21, 산출 hash == repo live/미러), lean 12스킬·design 프룬·dangling 0.
- 리뷰: **codex exec PASS_WITH_FIXES 88%** — H 0. M-1 데모 After 토큰 밖 raw 값(border 1px·SVG stroke 속성)→`--border-w`/`--icon-stroke`/currentColor 토큰화, M-2 터치 타깃·상태 규칙 부재→컨트롤 44px+hover/focus-visible/active/disabled+focus ring+transition 토큰, M-3 Before 정량 수치 불일치→CSS 재추출 통일(간격 12·radius 11·높이 5·폰트 10, 측정 범위 명시), L-1 line count 오기→제거. 반영 후 After raw design 값 0 재검증.

## Notes

- 사용자 의도 확인 과정: "design 스킬이 웹/앱 만들 때의 디자인 스킬 아닌가?" → 기존 스킬은 절차 게이트(미적 품질 규칙 부재) 설명 → 외부 사양서 제공 → 분석(콘텐츠 상급/구조 부적합) → AskUserQuestion으로 흡수 재설계 확정 → 비교 데모 검증 → 구현.
- 금지 폰트 완화 근거: 기존 프로젝트가 Inter 채택 중이면 "기존 토큰 존중" 원칙과 충돌 — "신규 선택 시 회피"로 조정해 두 원칙 정합.
- 진단 산출물(당초 소보수 G1~G5)은 재설계에 흡수 — 별도 버전 없음.

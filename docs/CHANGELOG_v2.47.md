# CHANGELOG v2.47 — codemap 초기 부트스트랩 절차

> 날짜: 2026-08-10 | 기반: v2.46 | 스킬 수: **21 불변**
> 한 줄: 설치가 codemap 템플릿만 만들고 기존 코드베이스를 스캔하지 않던 공백을, codemap SKILL의 정식 절차로 메웠다.

---

## 1. 문제 (실관측)

PawPad 설치(`-Upgrade` 포함)는 `.claude/codemap/_index.md`를 **빈 템플릿으로만** 생성한다. codemap SKILL에는 증분 갱신 규칙("새 화면 만들면 INDEX에 추가")만 있고, **이미 코드가 쌓인 프로젝트에 처음 들어왔을 때 무엇을 해야 하는지가 없다.**

결과:

- 신규 도입 프로젝트는 codemap이 사실상 비어 있는 채로 운영된다.
- 심볼 lookup은 계속 miss → 에이전트가 소스를 통째로 스캔 → 토큰 2~3배.
- 사용자 체감은 "codemap이 프로젝트 시작부터 안 만들어진다".

실사례: **TeamPitch_2.0** — 2026-07-17 v2.46 설치. 배포본 자체는 정상(스킬 21종·훅·미러 md5 전량 일치)이었으나, 2026-08-10 시점 codemap은 role/권한 1개 도메인 5KB뿐이었다. `lib/` 실제 규모는 115개 dart 파일. 즉 **설치는 성공했는데 codemap만 계속 비어 있던** 상태가 3주 이상 지속됐다.

## 2. 변경

### 2-1. codemap SKILL — `## 초기 부트스트랩 (기존 코드베이스에 처음 도입할 때)` 신설

| 구성 | 내용 |
|---|---|
| 발동 판정 | 코드 수정 세션 ON START에 **등록 심볼 < 10 && 소스 파일 >= 30**이면 1회 제안. 거절 시 그 세션 재제안 금지. 신규(빈) 프로젝트는 대상 아님 |
| 스캔 범위 | 소스 루트만. generated 제외(기존 `### generated 제외` 패턴을 스택별로 치환) |
| 등록 기준 | 포함 = public 진입점(클래스/화면/route/서비스/repository/모델 진입점/상태 provider·store/주요 public 메서드). 제외 = private 헬퍼, 1줄 getter, 뷰 내부 렌더 로직, 순수 표현용 서브컴포넌트 |
| 규모 분기 | 소스 < 40 파일 = 인라인. >= 40 파일 = `code-delegate` 배치 위임(기능/폴더 기준 3~4배치, 배치당 30~40파일) |
| 위임 규약 | 각 서브는 `.claude/codemap/_staging/{batch}.md`에 **직접 Write**, **반환은 4줄 요약만**(staging 경로 / 심볼 수 / 파일 수 / 특이사항). 심볼 본문을 부모로 반환하면 위임 이득이 사라진다. 서브의 `_index.md` 직접 편집 금지(owner 권한) |
| 병합 | owner가 staging 합침. 기존 MAP·HOT·수기 등록 섹션 **보존**(덮어쓰기 금지), 중복 심볼만 제거, `_staging/` 제거 |
| 크기 판정 | 합계 30KB 초과면 flat 유지 금지 → 즉시 Phase B(trim-router). leaf 4KB 근접 시 layer(data/state/ui) 분할 |
| 검증 게이트 | (a) size cap 전수 PASS (b) 무작위 심볼 5~6개 path:line 실파일 대조 **전건 일치**. 불일치 시 해당 배치 재작업 |

### 2-2. Phase B 전환 시 `_index.md` 경로 사멸 차단

trim-router로 전환하면 진입점이 `_root.md`로 바뀌는데, Session Protocol step7은 `_index.md`를 가리키고 있었다. 그대로 두면 **전환한 프로젝트의 ON START read가 죽는 파일을 향한다.**

- SKILL에 규약 명문화: `_index.md`는 삭제하지 않고 **라우팅 스텁**으로 남긴다(3~5줄 포인터 + "심볼표 없음, 통째 read 금지").
- Session Protocol step7 문구 수정 — `_root.md`(Phase B) 있으면 그것만, 없으면 `_index.md` MAP+HOT. 부트스트랩 제안 조건도 이 줄에 포함.

## 3. 표면 (동기 대상)

| 표면 | 파일 |
|---|---|
| SKILL embed | `pawpad-setup.ps1` codemap SKILL 히어독 |
| Session Protocol step7 (템플릿 2벌) | `pawpad-setup.ps1` CLAUDE/AGENTS 템플릿 |
| Session Protocol step7 (live 2벌) | `CLAUDE.md`, `AGENTS.md` |
| live 스킬 + Codex 미러 | `.claude/skills/codemap/SKILL.md`, `.agents/skills/codemap/SKILL.md` (self `-Upgrade`로 재생성) |
| 버전 앵커 | `pawpad-setup.ps1`(헤더·`$ver`), `README.md`, `GUIDE.md`, `USAGE.md`, `PAWPAD_VERSIONS.md` |

## 4. 근거가 된 실증 (TeamPitch_2.0)

절차의 각 항목은 즉석 설계가 아니라 **실제로 돌려서 나온 수치**다.

- 배치 분할: `member/club/auth`(38) · `team/schedule/match`(37) · `community/dues/home/core/app`(40) — sonnet 서브 3개 병렬
- 서브 토큰: 각 185k / 204k / 203k (합계 ~59만) 이 **전부 서브 컨텍스트에 격리**, 부모는 4줄 요약 3개만 흡수
- 결과: 283 심볼(신규 255 + 기존 role/권한 23 보존), 40.5KB → Phase B 전환
- 최종 구조: `_index.md` 스텁 531B + `_root.md` 1882B + `keywords.md` 3162B + `features/` 25 leaf(최대 3593B)
- 검증: size cap 28파일 전수 PASS / 무작위 심볼 6건 path:line 실측 **6/6 일치**
- 부수 발견: dead 화면 2종(참조 0건) 적발 → 별도 제거. 심볼명 오류 1건 교정

## 5. 비고

- 스킬 수 21 불변. 신규 스킬을 만들지 않고 codemap SKILL 내 섹션으로 흡수 — pawpad lean 기조 유지.
- 발동을 "자동 1회 제안"으로 정한 이유: 수동 호출만 두면 사용자가 필요성을 스스로 알아야 하는데, TeamPitch가 3주간 방치된 것이 정확히 그 실패 경로다. 다만 임계값(심볼<10 && 소스>=30)으로 소규모·신규 프로젝트에는 발동하지 않게 했고, 거절 시 재제안을 막아 과추천을 차단했다.
- 기존 설치는 `-Upgrade` 재실행 필요.

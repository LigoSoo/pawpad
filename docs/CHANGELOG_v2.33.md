# CHANGELOG v2.33 — code-delegate 스킬 (코딩 단계 서브에이전트 위임)

> 신규 스킬 18→19. 기획·구조 설계는 상위 모델(Opus 4.8)로, 코딩은 사용자 선택 모델(Sonnet 등)의 코딩 서브에이전트로 위임해 부모 컨텍스트를 린하게 유지하고 토큰을 절감한다. clarity 게이트 분석에서 "서브에이전트=독립 context window → 부모는 전달 프롬프트+최종 메시지만 흡수"가 검증되어 스킬화.

## 배경
ON START + 설계로 부모 컨텍스트가 ~30%까지 차고, 인라인 코딩이 60%까지 빠르게 밀어올려 checkpoint/handoff·세션 전환을 반복해야 했다. 코딩은 하위 모델도 잘 하므로, 코딩 단계를 별도 모델의 서브에이전트에 위임하면 코딩 반복(파일 read/write·도구호출)이 서브 context에 격리되어 부모는 린 유지 + 토큰 비용 하락.

## 변경: code-delegate 스킬 (접근법 A — instruction 스킬 + 자동제안)
- **트리거**: `/code-delegate [모델]` 또는 구현 진입 경계 자동제안(SPEC_READY/written 설계 직후, 강제 X).
- **위임 적합성 게이트**: ① written 설계 존재(spec/lane) ② 코딩 단계 ③ 격리 가능. 미충족 시 인라인 권장(대화-only 설계면 이점 반감 경고).
- **절차**: 모델 선택(AskUserQuestion, 복잡도 기준 추천 1개) → Agent 도구 spawn(선택 model + spec/lane/codemap **포인터 read 지시** + 작업범위 + 반환형식) → 서브는 **요약+변경파일+검증상태** 반환(전체 코드 dump 금지) → 부모 검토·피드백(SendMessage 이어가기 또는 재dispatch). lane/DoD는 부모 소유.
- **런타임**: Claude Code 주력(Task 도구 model 오버라이드 opus/sonnet/haiku/fable). Codex는 per-call 모델선택 메커니즘이 달라 수동 세션 전환 폴백 안내.

## 분석 근거 (의도 타당성)
- 서브에이전트는 독립 context. 부모는 전달 프롬프트 + 서브 최종 메시지만 흡수 → 코딩 반복 격리 → 부모 린 유지(검증된 패턴: Claude Code Explore 서브에이전트).
- 컨텍스트 절감은 과금 방식 무관 확실. 토큰 비용은 API 과금=$ 직접 절감 / 구독(Pro/Max)=rate-limit 여유 환산.
- 한계: 부모는 매 반환을 흡수(다회 피드백이면 누적, 단 코딩 본체 격리라 이득 유지) → 반환 요약 유지가 핵심. written 설계 전제(없으면 dump 필요).

## 배포 표면 동기
- `.claude/skills/code-delegate/SKILL.md` (live) + `.agents/skills/code-delegate/SKILL.md` (Codex 미러) + `pawpad-setup.ps1` 임베드(`@'...'@` 리터럴).
- 자동제안 4표면: `CLAUDE.md`/`AGENTS.md` `### 자동제안`(구현 진입 경계 1줄) + setup `$tmplClaudeMd`/`$tmplAgentsMd` 임베드.
- 스킬 수 18→19: `SKILLS_MANIFEST.md` + setup 임베드 매니페스트 + `.codex/config.json` skills 배열 + setup 임베드 config 배열 + README/GUIDE 카운트.
- 버전 v2.33: setup 헤더/STATUS/`$ver`/완료메시지/누적 스킬수 + README/GUIDE/USAGE + 이력.
- `docs/CHANGELOG_v2.33.md`(신규) + `.claude/codemap/_index.md`(codeDelegateSkill + v233Changelog).

## 범위 외
- Codex 동등 모델-핀 지원(별도 lane). 자동 코딩단계 감지의 hook화(instruction 기반 유지).

## 검증
PSParser parse-ok / live==embed==.agents 미러(code-delegate 본문) / 자동제안 embed==live(CLAUDE 4표면) / 스킬 19 일관(.claude==.agents==config==manifest==embed) / stale `v2.32 FROZEN` 라이브 0(이력 `> v2.32:`·STATUS 이전 제외) / security 🔴0 / **행동 smoke**(실제 코딩 서브에이전트 1회 dispatch: 모델선택→spawn→요약반환 동작).

## 프로세스
clarity(임계값 30, r2 PASS 23 + 접근법 게이트 A 선택) → 분석(의도 타당성 판정) → 구현 → self-verify + 행동 smoke → codex exec 자율 리뷰(설치 스크립트 변경) → 동결.

# CHANGELOG v2.29 — review 스킬 (문서형 리뷰 라운드트립)

## 추가: 신규 `review` 스킬 (count 17 → 18)

### 배경
`codex exec` 자율 리뷰는 repo 전체를 재탐색해 토큰을 대량 소모(실측 1회 247k). 대부분 리뷰는 변경 범위가 한정적 → 저비용 문서형 리뷰 흐름 필요.

### 신규 스킬: review
- `.claude/skills/review/SKILL.md` — 문서형 크로스에이전트/세션 리뷰 **라운드트립**.
- 트리거 `/review [request|do]` — lane state로 **자동 분기**(REVIEW_REQUESTED 유무).
- 흐름: 요청측 review-request 작성 → state=REVIEW_REQUESTED → 리뷰측(다른 세션/Codex↔Claude)이 **직접 검증**하며 리뷰 → review-result → state=REVIEW_DONE → 요청측 수정.
- **work owner 불변** + lane `reviewer`/`review` 필드(리뷰어는 검토만, work lane 미점유).
- 라운드: result 번호(review-NN) 추적 + REQUESTED↔DONE 토글, **종결은 요청측 재량**.
- **직접 검증 체크리스트 필수**(요약 맹신 → 저자 맹점 상속 방지).
- `codex exec` 자율 리뷰는 **보완 관계**(고위험·배포본·광범위 변경 에스컬레이션). 대체 아님.
- 산출물: `reviews/{feature}-review-prompt-NN.md`(request) · `{feature}-review-NN.md`(result).

### state machine 확장
- 신규 state 2종: `REVIEW_REQUESTED`, `REVIEW_DONE`.
- 동기: `.codex/config.json` stateEnum(live+embed) · `_wip.md` State표·필드(reviewer/review) · `AGENTS.md` state 마커.
- `CLAUDE.md`/`AGENTS.md` Hybrid Lane Rule에 reviewer 예외(리뷰어는 review state·경로만 갱신, work 미수정).

### 라우팅/자동제안
- CLAUDE/AGENTS 자동제안에 "구현완료 경계: 고위험/배포본 변경 완료 직전 `/review` 권장(강제 X)" 추가. DoD 필수 게이트 아님.
- Active Skills 첨자에 `review` 추가. 선택지 질문 체크박스 대상에 review 포함.

### 전 표면 동기
setup.ps1 $ver 2.29 · 헤더/STATUS · review 스킬 임베드(`@'...'@`) · $tmplClaudeMd/$tmplAgentsMd(Hybrid Lane Rule·자동제안·Active Skills·state 마커) · 임베드 _wip(State표·필드)·config(stateEnum+skills) · SKILLS_MANIFEST 17→18 · .agents 미러 · codemap · README/GUIDE/USAGE.

### 검증
PSParser 0 / 스킬 수 18 일관(.claude==.agents==config==manifest==embed) / stateEnum 2종 4곳 동기 / embed==live / BOM-less / -Upgrade 병합 / 라운드트립 동작 시나리오 / **dogfood**(완성된 review 스킬로 자기 구현 리뷰).

### 프로세스
clarity PASS(29) → grill-me(6분기) → to-prd → 구현 lane. spec: `.claude/pawpad/specs/review-skill.md`.

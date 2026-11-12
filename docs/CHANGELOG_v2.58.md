# CHANGELOG v2.58 — statusline 캐시 모드 (opt-in)

- 날짜: 2026-11-12
- 기준: v2.57
- 스킬 수: **22 불변**
- 훅: `statusline.ps1` · `statusline.sh` 에 캐시 칸 추가 (환경변수로 켤 때만 출력)
- 기본 동작: **불변** — 환경변수를 켜지 않으면 statusline 출력은 v2.57과 같다
- CLAUDE.md / AGENTS.md 템플릿: 불변

---

## 1. 왜

사용자 요청: 프롬프트 캐시가 얼마나 읽히고 쓰였는지, 캐시가 얼마나 더 살아 있는지 화면에서 보고 싶다.

## 2. 켜는 법

환경변수 `PAWPAD_CACHE_STATUS` 를 `1` / `on` / `true` 중 하나로 둔다. `-Upgrade` 가 프로젝트 `.claude/settings.json` 을 다시 쓰므로 **사용자 설정**(`~/.claude/settings.json`)에 두는 것을 권장한다.

```json
{ "env": { "PAWPAD_CACHE_STATUS": "1" } }
```

끄려면 값을 지우거나 `0` 으로 둔다.

## 3. 표시

```
ctx 5% (53k/1M) | Opus | 📡 ... | cache R 96k · W 6k(1h) · ⏳ 59:53
```

| 칸 | 뜻 | 출처 |
|---|---|---|
| `R` | 이번 응답에서 캐시로 읽은 토큰 | transcript 마지막 응답 `usage.cache_read_input_tokens` |
| `W` | 이번 응답에서 캐시에 새로 쓴 토큰 | `usage.cache_creation_input_tokens` |
| `(1h)` / `(5m)` | 캐시 TTL | 가장 최근 쓰기의 `cache_creation.ephemeral_1h_input_tokens` / `ephemeral_5m_input_tokens` 중 0이 아닌 쪽. 기록이 없으면 5m |
| `⏳ mm:ss` | 캐시가 살아 있는 남은 시간 | 마지막 응답 시각 + TTL − 지금. 남은 비율 25% 이상 초록 · 10% 이상 노랑 · 그 아래 빨강 |
| `⏳ expired` | TTL이 지났다 | 다음 요청은 캐시를 다시 쓴다 |
| `💥reset` | 이번 응답에서 캐시가 깨졌다 | 직전 응답보다 read가 절반 아래로 줄고, write가 직전 (read+write)의 절반을 넘고, write ≥ 1024 |
| `cache -` | 캐시 기록 없음 | transcript 없음 · 응답 없음 · read와 write 모두 0 |

같은 `message.id` 가 content block마다 여러 줄로 기록되므로 1건으로 합쳐서 센다.

## 4. 읽는 법 — 캐시 구조

- 읽기와 쓰기의 TTL은 따로 있지 않다. 캐시 항목 하나에 TTL이 하나 있고, 쓸 때 5m 또는 1h로 정해진다. 읽을 때마다 그 항목의 남은 시간이 처음 TTL로 다시 채워진다.
- TTL 말고도 캐시가 깨지는 경우: 앞부분 내용 변경(MCP 도구 변경 · CLAUDE.md 수정 · `/compact` · `/clear` · 되감기 · thinking 설정 변경 등), 모델 전환, 서버의 조기 삭제. 이런 경우는 미리 알 수 없고 다음 응답의 `💥reset` 으로 드러난다.

## 5. 한계

- 남은 시간은 **추정값**이다. 서버가 TTL 전에 지운 경우는 알 수 없다.
- statusline은 이벤트가 있을 때만 다시 그려진다. 가만히 있는 동안에는 숫자가 줄지 않는다.
- transcript 끝 200줄만 본다. 그 안에 쓰기 기록이 없으면 TTL을 5m로 가정한다.

## 6. 변경 파일

- `.claude/hooks/statusline.ps1` · `.claude/hooks/statusline.sh` (live + `pawpad-setup.ps1` 임베드, live == 임베드 확인)
- `pawpad-setup.ps1` 헤더 · `$ver` · 완료 요약
- `README.md` · `GUIDE.md` · `USAGE.md` · `PAWPAD_VERSIONS.md`
- codemap `features/hooks.md` · `features/changelogs-recent.md`

## 7. 검증

- `statusline.ps1`: 이 세션 실제 transcript → `cache R 96k · W 6k(1h) · ⏳ 59:53`. 꺼짐 상태 출력이 이전과 같음.
- 가짜 transcript 3종: 1h 쓰기 후 reset → `💥reset` + 초록 `59:43` / 5m 읽기만 250초 경과 → `(5m)` 노랑 `00:47` / 5m 6분 경과 → 빨강 `expired`.
- `statusline.sh`: `bash -n` 문법 통과. **실행 검증 안 함** — 이 머신에 jq가 없다. Mac/Linux 설치처에서 확인 필요.
- `pawpad-setup.ps1`: PowerShell 문법 검사 오류 0.

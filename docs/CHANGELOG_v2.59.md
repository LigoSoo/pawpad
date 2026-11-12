# CHANGELOG v2.59 — 캐시 만료 전 데스크톱 알림 (opt-in)

- 날짜: 2026-11-12
- 기준: v2.58
- 스킬 수: **22 불변**
- 훅: 신규 `cache-watch.ps1` · `cache-watch.sh` (Claude 전용). settings.json `SessionStart`·`Stop`에 두 번째 훅으로 등록
- 기본 동작: **불변** — 스위치를 켜지 않으면 훅이 바로 끝난다(무출력)
- 설치 옵션: `-EnableCacheStatus` 신규
- CLAUDE.md / AGENTS.md 템플릿: 불변

---

## 1. 왜

사용자 요청: 캐시 남은 시간을 보고(v2.58), **만료되기 전에 작업을 이어서 할 수 있게** 하고 싶다.

응답이 끝난 순간엔 캐시가 막 재충전돼 남은 시간이 항상 TTL 전체다. 캐시가 사라지는 건 응답 뒤 쉬는 동안이다.
그래서 statusline(화면을 보고 있을 때만 의미)으로는 부족하고, 쉬는 동안 기다렸다가 알려 주는 타이머가 필요하다.

## 2. 동작

| 시점 | 동작 |
|---|---|
| Stop(응답 끝) | transcript 마지막 응답 usage로 TTL 판별(`ephemeral_1h` → 3600s, 그 외 300s)·마지막 캐시 사용 시각 기록 → `.ctxdb/.state/cache-watch.json`에 새 토큰 → 숨은 감시 프로세스 1개 실행 → 훅은 바로 끝(무출력) |
| 감시 중 (30s마다) | 토큰이 바뀌었거나(새 응답이 다시 무장) transcript에 마지막 응답 뒤 user/assistant 기록이 생기면(새 입력 = 캐시 재충전) 조용히 종료 |
| 알림 시각 | 만료 − 선행 시간에 OS 알림 1회: `PawPad · {프로젝트} · 캐시 N분 남음` / `지금 이어서 입력하면 캐시가 유지됩니다 (만료 HH:MM, TTL 60분)` |
| SessionStart(새 세션·/clear·재개) | 토큰을 cancel로 → 이전 세션 알림 중단(이전 prefix는 새 세션에서 재사용되지 않음) |

- 만료 시각 = 마지막 응답 시각 + TTL. 캐시는 **읽기만 해도 TTL이 다시 채워진다**(실제 규칙) → 마지막 응답 기준.
- 선행 시간 기본: 1h TTL = 600s(10분 전), 5m TTL = 60s(1분 전). `PAWPAD_CACHE_ALERT_LEAD=<초>`로 바꾼다.
- 알림: Windows 10/11 토스트(PS 5.1 WinRT, 실패 시 트레이 풍선) / macOS `osascript` / Linux `notify-send`.
- 감시 프로세스는 프로젝트마다 사실상 1개(이전 것은 토큰 교체를 보고 30s 안에 빠진다).

## 3. 켜는 법

같은 스위치 `PAWPAD_CACHE_STATUS=1|on|true` (v2.58 statusline 캐시 칸과 공유).

- 설치 시 자동: `pawpad-setup.ps1 -Upgrade -EnableCacheStatus` → 이 머신 `~/.claude/settings.json`의 `env`에 병합(원본 `.pawpad-bak` 백업, 이미 켜져 있으면 SKIP). 새 세션부터 적용.
- 직접: `~/.claude/settings.json`에 `{ "env": { "PAWPAD_CACHE_STATUS": "1" } }`.

## 4. 한계 (실제 캐시 초기화 조건 중 미리 알 수 없는 것)

- 서버가 TTL 전에 캐시를 일찍 축출하는 경우 — 감지 불가, 실제 만료가 더 이르다.
- prefix 변경(시스템 프롬프트·도구 목록 변경, 모델 전환, 압축) — 다음 요청에서 캐시가 깨진다. statusline `💥reset`이 사후에 잡는다.
- 마지막 응답 기록 시각은 요청 시작보다 조금 늦다(응답 길이만큼) → 남은 시간이 최대 수십 초 과대. 선행 시간이 흡수한다.
- 원격(폰 Remote Control)으로는 알림이 가지 않는다 — PC 데스크톱 알림만.
- `.sh`는 `jq`가 없으면 조용히 끝난다(statusline.sh와 같은 전제).

## 5. 검증

- 단독(Windows, PS 5.1): 가짜 transcript(마지막 응답 = 지금 − 3600 + 615s, 1h) + `PAWPAD_CACHE_ALERT_DRYRUN` → 15s 뒤 `PawPad · p1 · 캐시 10분 남음 | … 만료 21:34, TTL 60분` 기록. 같은 조건에 user 줄 추가 → 기록 없음. 감시 프로세스 잔존 0.
- 새 설치(임시 폴더, `-Stack godot -Preset lean`): 69 created / 0 failed, `cache-watch.ps1`(BOM)·`.sh`(LF) 생성, settings.json SessionStart·Stop 훅 각 2개, JSON 유효.
- run-hook 경유 실제 토스트 1회 발화 후 감시 종료.
- `.sh`: `bash -n` 문법 통과. jq 없는 환경이라 실행 검증은 미실시.

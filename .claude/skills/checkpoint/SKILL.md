---
name: checkpoint
description: Context rollover gate. Use when the context window nears 50-60% to save lane/codemap/meta state so a new session can resume seamlessly.
---
# Checkpoint Skill - Context Rollover Gate (Instruction)

## 목적
Context window 60% 도달 전 정리. 새 세션에서 끊김 없이 이어가기 위한 상태 보존.

## 성격
**Instruction skill**. agent가 이 SKILL.md를 보고 수동으로 파일을 갱신. PowerShell command 아님.

## 트리거
/checkpoint [강제]
- 50-60% context 추정 시 agent 또는 사용자가 호출
- /checkpoint 강제 -> 즉시 체크포인트 (% 무관)

## Context Window 임계값 (60% 기준)
| 상태       | %      | agent 액션 |
|-----------|--------|----------|
| 정상      | 0-50   | 계속 진행 |
| 체크포인트 | 50-60  | lane 파일/codemap 갱신, /checkpoint 권장 |
| 핸드오프  | 60-70  | /handoff 실행, snapshot 작성 |
| 전환권장  | 70-85  | 새 세션 시작 |
| 임계      | 85+    | 즉시 STOP, 작업 중단 후 handoff |

## % 추정 휴리스틱
LLM 자체 측정 불가. agent가 다음 신호로 추정:
- 50회 이상 응답
- 큰 파일(500줄+) 5회 이상 read
- 도구 호출 100회 이상
- 사용자 명시적 지정

위 신호 2개 이상 -> 50% 초과 추정.

## 실행 절차 (agent가 순차 수행)
1. 현재 작업 lane 파일 갱신:
   - 완료/미완 정리
   - 다음 단계 명시
   - 수정 중 파일 목록
2. codemap/_index.md 갱신:
   - 신규 심볼 추가
   - HOT 섹션 최신화
3. _meta.md 갱신 (해당 시):
   - 완료 항목 RECENT에 추가
4. _wip.md Active Lanes의 updated 필드 갱신
5. 60% 초과 추정 시 -> agent가 /handoff 권장 (사용자 안내)
6. 결과:
   - lane 파일이 다음 세션에서 즉시 재개 가능한 상태
   - 새 세션 ON START -> lane 파일 read -> 그대로 이어 작업

## 사용자 안내 메시지 (60% 초과 추정 시)
"Context 약 60% 추정. agent가 정리 권장:
1. lane 파일 갱신 완료
2. codemap 최신화
3. /handoff {to-agent} {feature} 실행 권장 (또는 새 세션 직접 시작)"

## /checkpoint 와 /handoff 차이
- /checkpoint : 같은 에이전트 새 세션에서 이어 작업 (저장만, snapshot 없음, owner 유지)
- /handoff   : 다른 에이전트에게 인수 (snapshot 생성, owner는 인수 시 변경)

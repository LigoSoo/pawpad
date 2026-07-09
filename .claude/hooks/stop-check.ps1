# Stop hook - 루프가드 후 8턴 정기저장 / L2 분할규칙 위반 / lane-close 백스톱 시 decision:block.
# session-aware turn-count. PreCompact가 최근 8턴 내 저장 유도했으면 checkpoint 중복 생략.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
$event = $null
try { $event = $raw | ConvertFrom-Json } catch {}
# block 재진입 가드. exit 0 즉시반환 아님 — 교정 응답의 Retrieval 선언을 파싱/계측은 해야 하므로
# (여기서 끊으면 백스톱이 요구한 선언이 영영 stats에 안 들어감), 판정(block)과 turn 증가만 생략한다.
$hookActive = ($event.stop_hook_active -eq $true)

$sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "manual" }

$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

# read-track(PostToolUse) 실측 델타: 직전 stop 이후 이번 턴에 쌓인 kind만 집계 (watermark 방식).
# session-start가 read-stats를 비우므로 mark에 session을 묶어 stale mark를 0으로 처리.
$rsPath = Join-Path $stateDir "claude-read-stats"
$mkPath = Join-Path $stateDir "claude-read-mark"
$rsAll = @()
if (Test-Path $rsPath) { $rsAll = @(Get-Content -LiteralPath $rsPath -Encoding UTF8 -ErrorAction SilentlyContinue) }
$mark = 0
if (Test-Path $mkPath) {
    $mk = @(Get-Content -LiteralPath $mkPath -Encoding UTF8 -ErrorAction SilentlyContinue)
    if ($mk.Count -ge 2 -and $mk[0] -eq "session:$sessionId" -and $mk[1] -match "^read:(\d+)$") { $mark = [int]$Matches[1] }
}
if ($mark -gt $rsAll.Count) { $mark = 0 }   # 외부 truncate 방어
$delta = if ($rsAll.Count -gt $mark) { @($rsAll[$mark..($rsAll.Count - 1)]) } else { @() }
$srcDelta = @($delta -eq 'src').Count
$cmapDelta = @($delta -eq 'cmap').Count
Set-Content -Path $mkPath -Value @("session:$sessionId", "read:$($rsAll.Count)") -Encoding ascii

# retrieval hit/miss 계측: 방금 완료된 assistant 응답의 '📡 Retrieval:' 선언을 파싱해 누적 (statusline hit율 SoT).
# 미사용(선언 없음/미사용)은 기록 안 함 -> hit율 분모에서 제외. uuid dedupe로 동일 응답 재계수 방지.
$tp = if ($event) { [string]$event.transcript_path } else { "" }
if ($tp -and (Test-Path -LiteralPath $tp)) {
    try {
        $tlines = @(Get-Content -LiteralPath $tp -Tail 60 -Encoding UTF8 -ErrorAction SilentlyContinue)
        # transcript는 한 응답을 text/thinking/tool_use 각각 별개 엔트리로 기록 -> 첫 assistant 엔트리에서 break 시
        # thinking/tool_use라 text 놓침. 최근 window에서 유효 Retrieval 선언(중괄호 예시 제외)을 담은 가장 최근 text 엔트리를 찾음.
        $rl = ""; $rlUuid = ""
        for ($i = $tlines.Count - 1; $i -ge 0; $i--) {
            try { $o = $tlines[$i] | ConvertFrom-Json } catch { continue }
            if ($o.message.role -ne 'assistant') { continue }
            $txt = ""
            foreach ($c in @($o.message.content)) { if ($c.type -eq 'text') { $txt += [string]$c.text + "`n" } }
            if (-not $txt) { continue }
            # 앵커 필수: 'Retrieval:'/'codemap'을 라인 어디서나 찾으면 훅 자신을 논하는 산문("stop-check이 Retrieval: 라인에서 codemap hit을 파싱")이
            # 선언으로 오탐돼 지표가 거짓이 된다(훅 디버깅 세션마다 재발). 선두 앵커 + 백틱/중괄호 라인(인용·예시) 배제.
            # 이모지는 \uXXXX 서로게이트 이스케이프(.NET regex) — 무-BOM 재기록 시 리터럴 깨짐 방어
            $cand = ($txt -split "`n") | Where-Object { $_ -match '^\s*(?:\uD83D\uDCE1\s*)?Retrieval:\s*codemap\s' -and $_ -notmatch '[`{]' } | Select-Object -First 1
            if ($cand) { $rl = $cand; $rlUuid = [string]$o.uuid; break }
        }
        $seenPath = Join-Path $stateDir "claude-retrieval-seen"
        # 0-byte seen(session-start reset 직후)은 -Raw가 $null -> .Trim() NPE가 outer catch에 삼켜져 stats 미기록. "$()"로 null->"" 정규화.
        $seen = if (Test-Path $seenPath) { "$(Get-Content -LiteralPath $seenPath -Raw -Encoding UTF8)".Trim() } else { "" }
        if ($rl -and $rlUuid -and $rlUuid -ne $seen) {
            # 고정 순서 codemap | ctxdb | src 로 위치 분해 (키워드 매칭 시 경로 내 'codemap'/'ctxdb' 부분문자열과 충돌).
            # 구조 검증(3세그먼트 + 각 세그먼트 키워드)까지 통과해야 선언으로 인정 — 앵커만으론 부분 인용이 샌다.
            $segs = $rl -split '\|'
            if ($segs.Count -ge 3 -and $segs[1] -match 'ctxdb' -and $segs[2] -match 'src') {
                $cseg = $segs[0]
                $xseg = $segs[1]
                $rec = @()
                if ($cseg -match 'hit') { $rec += 'cmap:hit' } elseif ($cseg -match 'miss') { $rec += 'cmap:miss' }
                if ($xseg -match 'hit') { $rec += 'ctx:hit' } elseif ($xseg -match 'miss') { $rec += 'ctx:miss' }
                if ($rec.Count -gt 0) { Add-Content -Path (Join-Path $stateDir "claude-retrieval-stats") -Value $rec -Encoding ascii }
                Set-Content -Path $seenPath -Value $rlUuid -Encoding ascii
                # codemap을 hit/miss로 선언한 경우에만 백스톱 면제. '미사용' 선언은 면제 아님 ->
                # src를 여러 개 읽고 '미사용'이라 적는 허위 선언이 조용히 통과하던 구멍(분모 제외)을 막는다.
                if ($cseg -match 'hit' -or $cseg -match 'miss') { $script:freshDecl = $true }
            }
        }
    } catch {}
    # 가장 최근 assistant text 엔트리 (thinking/tool_use skip). lane-close + retrieval 백스톱 공용.
    $dTxt = ""; $dUuid = ""
    try {
        for ($i = $tlines.Count - 1; $i -ge 0; $i--) {
            try { $o2 = $tlines[$i] | ConvertFrom-Json } catch { continue }
            if ($o2.message.role -ne 'assistant') { continue }
            $t2 = ""
            foreach ($c2 in @($o2.message.content)) { if ($c2.type -eq 'text') { $t2 += [string]$c2.text + "`n" } }
            if ($t2) { $dTxt = $t2; $dUuid = [string]$o2.uuid; break }
        }
    } catch {}

    if (-not $hookActive) {
        # lane-close 백스톱 (v2.43): 마지막 assistant 응답이 작업 완료/종료를 선언했는데 _wip Active Lanes가 잔존하면
        # task-done 실행 리마인더 1회 (uuid dedupe). ON TASK DONE 미실행 -> stale lane -> resume 재제안 사고 방지.
        try {
            $wipP = ".claude/pawpad/_wip.md"
            if (Test-Path $wipP) {
                $wipRaw = "$(Get-Content -LiteralPath $wipP -Raw -Encoding UTF8)"
                $al = [regex]::Match($wipRaw, '(?sm)^## Active Lanes\s*(.*?)(?=^## |\z)')
                # stock _wip.md는 Active Lanes 섹션 안에 예시 블록('- feature-a:' 등)을 둔다 -> 예시 이후 절단 후 판정 (오탐 감쇄)
                $alBody = if ($al.Success) { ([regex]::Split($al.Groups[1].Value, '(?m)^\s*(?:예시|[Ee]xample)'))[0] } else { "" }
                if ($al.Success -and ($alBody -match '(?m)^\s*-\s+\S')) {
                    # 스킬명 'task-done' 언급 자체는 완료 선언 아님 -> 제거 후 매칭 (오탐 감쇄)
                    # 한글은 \uXXXX 이스케이프 (무-BOM .ps1을 PS5.1이 cp949로 읽어 한글 리터럴 깨짐): 작업|이슈|태스크 ... 완료|종료|마무리
                    $dTxtLC = $dTxt -replace 'task-done', ''
                    if ($dUuid -and $dTxtLC -match ('(\' + 'uC791\' + 'uC5C5|\' + 'uC774\' + 'uC288|\' + 'uD0DC\' + 'uC2A4\' + 'uD06C|task|lane)[^\r\n]{0,10}(\' + 'uC644\' + 'uB8CC|\' + 'uC885\' + 'uB8CC|\' + 'uB9C8\' + 'uBB34\' + 'uB9AC|done)')) {
                        $tdP = Join-Path $stateDir "claude-taskdone-warned"
                        $tdSeen = if (Test-Path $tdP) { "$(Get-Content -LiteralPath $tdP -Raw -Encoding UTF8)".Trim() } else { "" }
                        if ($dUuid -ne $tdSeen) {
                            Set-Content -Path $tdP -Value $dUuid -Encoding ascii
                            $script:laneClose = $true
                        }
                    }
                }
            }
        } catch {}

        # retrieval 백스톱 (v2.43): hit율은 선언 기반이라 선언을 빼먹으면 조용히 0이 된다. read-track 실측과 대조해
        # "codemap lookup 0 + src 직접읽기 2건 이상 + codemap hit/miss 선언 없음(누락 또는 '미사용')" = 미선언 full-scan으로
        # 보고 리마인더 1회 (uuid dedupe). src 1건은 면제 (이미 아는 파일 재편집 — CLAUDE.md가 라인 생략을 허용하는 케이스).
        try {
            if (-not $script:freshDecl -and $srcDelta -ge 2 -and $cmapDelta -eq 0 -and $dUuid) {
                $rwP = Join-Path $stateDir "claude-retrieval-warned"
                $rwSeen = if (Test-Path $rwP) { "$(Get-Content -LiteralPath $rwP -Raw -Encoding UTF8)".Trim() } else { "" }
                if ($dUuid -ne $rwSeen) {
                    Set-Content -Path $rwP -Value $dUuid -Encoding ascii
                    $script:retrMiss = $srcDelta
                }
            }
        } catch {}
    }
}

if ($hookActive) { exit 0 }   # 재진입: 계측/watermark는 위에서 끝냈고, block 재발행과 turn 증가는 생략 -> 루프 방지

$tcPath = Join-Path $stateDir "turn-count"

$turn = 0
if (Test-Path $tcPath) {
    $lines = Get-Content -Path $tcPath -Encoding UTF8
    if ($lines.Count -ge 2 -and $lines[0] -like "session:*") {
        if ($lines[0].Substring(8) -eq $sessionId -and $lines[1] -match "^turn:(\d+)$") { $turn = [int]$Matches[1] }
    } elseif (($lines -join "").Trim() -match "^\d+$") { $turn = [int](($lines -join "").Trim()) }
}
$turn++
Set-Content -Path $tcPath -Value @("session:$sessionId", "turn:$turn") -Encoding ascii

# PreCompact 중복 가드: 최근 8턴 내 compaction 저장 유도 있었으면 이번 checkpoint 생략
$lastCompactTurn = -1
$lcPath = Join-Path $stateDir "last-compact"
if (Test-Path $lcPath) {
    $lc = Get-Content -Path $lcPath -Encoding UTF8
    if ($lc.Count -ge 2 -and $lc[1] -match "^turn:(\d+)$") { $lastCompactTurn = [int]$Matches[1] }
}

# L2 분할 규칙 점검 (150줄 또는 ~2000토큰 초과 = 키워드 로드 시 토큰절약 무력화)
$oversized = @()
$l2dir = ".ctxdb/L2"
if (Test-Path $l2dir) {
    Get-ChildItem -Path $l2dir -Filter *.md -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $chars = if ($content) { $content.Length } else { 0 }
        $lcount = if ($chars -eq 0) { 0 } else { ([regex]::Matches($content, "`n").Count + 1) }
        $tok = [int]($chars / 3.5)
        if ($lcount -gt 150 -or $tok -gt 2000) { $oversized += ("{0}({1}L/~{2}tok)" -f $_.Name, $lcount, $tok) }
    }
}

$needsCheckpoint = ($turn % 8 -eq 0) -and -not ($lastCompactTurn -gt ($turn - 8))
$needsSplit = ($oversized.Count -gt 0)
if ($needsSplit) {
    $sig = $sessionId + "|" + ($oversized -join "|")
    $warnPath = Join-Path $stateDir "claude-oversize-warned"
    $lastSig = ""
    if (Test-Path $warnPath) { $lastSig = (Get-Content -Path $warnPath -Raw -Encoding UTF8).Trim() }
    if ($lastSig -eq $sig) { $needsSplit = $false } else { Set-Content -Path $warnPath -Value $sig -Encoding UTF8 }
}

$parts = @()
if ($needsCheckpoint) {
    $parts += "[checkpoint $turn turns] Update .claude/codemap/_index.md for new/changed symbols + refresh lane/_wip.md (on done: move to wip/done + _meta.md + git commit) + run context-saver to write .ctxdb/L2 and update INDEX.md AGENT SYNC."
}
if ($needsSplit) {
    $parts += ("[L2 split needed] " + ($oversized -join ", ") + " : exceeds 150 lines / 2000 tokens -> keyword load still pulls the whole file, defeating token savings. Split old entries into .ctxdb/L3/{name}-YYYY-MM.md or split by domain, then update INDEX/L1 pointers.")
}
if ($script:laneClose) {
    $parts += "[lane-close] The last response declares task completion but active lane(s) remain in .claude/pawpad/_wip.md. If the task is truly done, run the task-done skill now (full closure: lane -> wip/done move + _wip removal + _meta RECENT + tasklog + codemap + git commit). If not done, ignore this and continue."
}
if ($script:retrMiss) {
    $parts += ("[retrieval] read-track measured " + $script:retrMiss + " source reads this turn with zero .claude/codemap lookup and no codemap hit/miss declaration (line missing, or declared '미사용'). codemap lookup must precede source search. Grep .claude/codemap/_index.md for the symbol; if it is genuinely a miss, emit the Retrieval line declaring full-scan with the reason.")
}
if ($parts.Count -eq 0) { exit 0 }

$tail = if ($script:laneClose) { " If closing, execute task-done fully before stopping; otherwise report one line, then stop." }
        elseif ($script:retrMiss) { " Emit the missing Retrieval line (one line, honest hit/miss), then stop." }
        else { " Report one line, then stop." }
$reason = ($parts -join " ") + $tail
@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress | Write-Output
exit 0

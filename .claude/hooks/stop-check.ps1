# Stop hook - 루프가드 후 8턴 정기저장 / L2 분할규칙 위반 / lane-close 백스톱 시 decision:block.
# session-aware turn-count. PreCompact가 최근 8턴 내 저장 유도했으면 checkpoint 중복 생략.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
$event = $null
try { $event = $raw | ConvertFrom-Json } catch {}
if ($event.stop_hook_active -eq $true) { exit 0 }   # block 재진입 -> 루프 방지

$sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "manual" }

$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

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
            $cand = ($txt -split "`n") | Where-Object { $_ -match 'Retrieval:' -and $_ -match 'codemap' -and $_ -notmatch '\{' } | Select-Object -First 1
            if ($cand) { $rl = $cand; $rlUuid = [string]$o.uuid; break }
        }
        $seenPath = Join-Path $stateDir "claude-retrieval-seen"
        # 0-byte seen(session-start reset 직후)은 -Raw가 $null -> .Trim() NPE가 outer catch에 삼켜져 stats 미기록. "$()"로 null->"" 정규화.
        $seen = if (Test-Path $seenPath) { "$(Get-Content -LiteralPath $seenPath -Raw -Encoding UTF8)".Trim() } else { "" }
        if ($rl -and $rlUuid -and $rlUuid -ne $seen) {
            # 고정 순서 codemap | ctxdb | src 로 위치 분해 (키워드 매칭 시 경로 내 'codemap'/'ctxdb' 부분문자열과 충돌).
            $segs = $rl -split '\|'
            $cseg = if ($segs.Count -ge 1) { $segs[0] } else { "" }
            $xseg = if ($segs.Count -ge 2) { $segs[1] } else { "" }
            $rec = @()
            if ($cseg) { if ($cseg -match 'hit') { $rec += 'cmap:hit' } elseif ($cseg -match 'miss') { $rec += 'cmap:miss' } }
            if ($xseg) { if ($xseg -match 'hit') { $rec += 'ctx:hit' } elseif ($xseg -match 'miss') { $rec += 'ctx:miss' } }
            if ($rec.Count -gt 0) { Add-Content -Path (Join-Path $stateDir "claude-retrieval-stats") -Value $rec -Encoding ascii }
            Set-Content -Path $seenPath -Value $rlUuid -Encoding ascii
        }
    } catch {}
    # lane-close 백스톱 (v2.43): 마지막 assistant 응답이 작업 완료/종료를 선언했는데 _wip Active Lanes가 잔존하면
    # task-done 실행 리마인더 1회 (uuid dedupe). ON TASK DONE 미실행 -> stale lane -> resume 재제안 사고 방지.
    try {
        $wipP = ".claude/pawpad/_wip.md"
        if (Test-Path $wipP) {
            $wipRaw = "$(Get-Content -LiteralPath $wipP -Raw -Encoding UTF8)"
            $al = [regex]::Match($wipRaw, '(?sm)^## Active Lanes\s*(.*?)(?=^## |\z)')
            if ($al.Success -and ($al.Groups[1].Value -match '(?m)^\s*-\s+\S')) {
                # retrieval 탐색과 별개로 "가장 최근 assistant text 엔트리"를 찾음 (thinking/tool_use skip)
                $dTxt = ""; $dUuid = ""
                for ($i = $tlines.Count - 1; $i -ge 0; $i--) {
                    try { $o2 = $tlines[$i] | ConvertFrom-Json } catch { continue }
                    if ($o2.message.role -ne 'assistant') { continue }
                    $t2 = ""
                    foreach ($c2 in @($o2.message.content)) { if ($c2.type -eq 'text') { $t2 += [string]$c2.text + "`n" } }
                    if ($t2) { $dTxt = $t2; $dUuid = [string]$o2.uuid; break }
                }
                # 스킬명 'task-done' 언급 자체는 완료 선언 아님 -> 제거 후 매칭 (오탐 감쇄)
                # 한글은 \uXXXX 이스케이프 (무-BOM .ps1을 PS5.1이 cp949로 읽어 한글 리터럴 깨짐): 작업|이슈|태스크 ... 완료|종료|마무리
                $dTxt = $dTxt -replace 'task-done', ''
                if ($dUuid -and $dTxt -match ('(\' + 'uC791\' + 'uC5C5|\' + 'uC774\' + 'uC288|\' + 'uD0DC\' + 'uC2A4\' + 'uD06C|task|lane)[^\r\n]{0,10}(\' + 'uC644\' + 'uB8CC|\' + 'uC885\' + 'uB8CC|\' + 'uB9C8\' + 'uBB34\' + 'uB9AC|done)')) {
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
}

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
if ($parts.Count -eq 0) { exit 0 }

$tail = if ($script:laneClose) { " If closing, execute task-done fully before stopping; otherwise report one line, then stop." } else { " Report one line, then stop." }
$reason = ($parts -join " ") + $tail
@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress | Write-Output
exit 0

# PostToolUse(Read|Grep|Glob) - retrieval 계측. 분류: cmap / ctx / src. 관측 전용(항상 exit 0).
$ErrorActionPreference = 'SilentlyContinue'
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if (-not $raw.Trim()) { exit 0 }
    $ev = $raw | ConvertFrom-Json
    $ti = $ev.tool_input
    $tn = if ($ev.tool_name) { [string]$ev.tool_name } else { '' }
    $target = ''
    if ($ti) {
        if ($ti.file_path) { $target = [string]$ti.file_path }
        elseif ($ti.path) { $target = [string]$ti.path }
        # path 없는 검색은 tool별 경로형 필드로 폴백 (v2.43 B4): Glob의 pattern은 경로 glob,
        # Grep의 glob은 경로 필터. Grep의 pattern은 내용 regex라 경로가 아니므로 제외.
        elseif ($tn -eq 'Glob' -and $ti.pattern) { $target = [string]$ti.pattern }
        elseif ($tn -eq 'Grep' -and $ti.glob) { $target = [string]$ti.glob }
    }
    $target = $target -replace '\\', '/'
    $kind = 'src'
    if ($target -match '(^|/)\.claude/codemap(/|$)') { $kind = 'cmap' }
    elseif ($target -match '(^|/)\.ctxdb(/|$)') { $kind = 'ctx' }
    elseif ($target -match '(^|/)(\.claude|\.agents|\.codex)(/|$)') { exit 0 }
    else {
        # src = "이 repo의 소스 파일". 아래는 소스가 아니므로 미집계 —
        # 계수하면 백스톱이 "codemap 없이 소스를 뒤졌다"고 오판하고, 정직한 '미사용' 선언은 B3가 막아
        # 에이전트가 빠져나갈 수 없는 block 교착에 빠진다(실사례: 스크린샷 4장 read -> 매 턴 block).
        # (1) 자산/바이너리: 스크린샷·아이콘·미디어는 codemap lookup 대상이 아니다.
        $assetExt = @('.png','.jpg','.jpeg','.gif','.webp','.bmp','.ico','.svg','.pdf','.zip','.gz',
                      '.mp4','.mov','.mp3','.wav','.ttf','.otf','.woff','.woff2','.exe','.dll','.so','.dylib','.bin')
        $ext = ''
        try { $ext = [System.IO.Path]::GetExtension($target).ToLowerInvariant() } catch {}
        if ($ext -and $assetExt -contains $ext) { exit 0 }
        # (2) repo 밖: scratchpad/temp/타 repo 절대경로. 상대경로는 repo 내부로 간주.
        $cwd = if ($ev.cwd) { ([string]$ev.cwd) -replace '\\', '/' } else { '' }
        if ($cwd -and [System.IO.Path]::IsPathRooted($target)) {
            $root = $cwd.TrimEnd('/') + '/'
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
        }
    }
    $stateDir = ".ctxdb/.state"
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    Add-Content -Path (Join-Path $stateDir "claude-read-stats") -Value $kind -Encoding ascii
} catch {}
exit 0

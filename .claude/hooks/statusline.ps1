# statusLine - 현재 세션 컨텍스트 윈도우 사용량(%) 표시.
# 1순위: stdin JSON의 context_window 필드 (Claude Code v2.1.132+, 모델별 실제 한도 + /context 동일 계산).
# 2순위(구버전 폴백): transcript JSONL 마지막 usage + model.id 기반 한도 테이블.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-TailLines {
    # stop-check.ps1과 동일 구현. PS 5.1 `Get-Content -Tail`은 -Encoding 지정 시 초선형 붕괴(16MB에서 26.79s),
    # -Encoding을 빼면 ANSI로 읽혀 비-ASCII가 깨진다. StreamReader(UTF-8) 1패스 + 링버퍼로 둘 다 회피(0.13s).
    param([string]$Path, [int]$Count)
    if ($Count -le 0) { return @() }
    $ring = New-Object string[] $Count
    $n = 0
    $fs = $null; $sr = $null
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding $false), $true)
        while ($null -ne ($ln = $sr.ReadLine())) { $ring[$n % $Count] = $ln; $n++ }
    } catch { return @() } finally {
        if ($sr) { $sr.Dispose() } elseif ($fs) { $fs.Dispose() }
    }
    if ($n -eq 0) { return @() }
    $c = [Math]::Min($n, $Count)
    $out = New-Object string[] $c
    for ($i = 0; $i -lt $c; $i++) { $out[$i] = $ring[(($n - $c + $i) % $Count)] }
    return $out   # `,$out` 금지 (호출부 @()가 배열을 1요소로 감싸 파싱 무력화)
}

# stdin은 UTF-8. 콘솔 코드페이지(CP949 등)에 의존하는 [Console]::In 대신 raw 바이트를 UTF-8로 디코딩
# (Korean username 등 non-ASCII transcript_path가 깨져 JSON 파싱 실패하던 버그 방지).
$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { return }
$model = $j.model.display_name
$used = 0
$limit = 0
$cw = $j.context_window
if ($cw -and [long]$cw.context_window_size -gt 0) {
    # 공식 필드: context_window_size = 모델별 실제 한도(200k/1M). used = input+cache_read+cache_creation.
    $limit = [long]$cw.context_window_size
    $cu = $cw.current_usage
    if ($cu -and $null -ne $cu.input_tokens) {
        $used = [long]$cu.input_tokens + [long]$cu.cache_read_input_tokens + [long]$cu.cache_creation_input_tokens
    } elseif ($null -ne $cw.total_input_tokens) {
        # current_usage는 첫 API 호출 전/compact 직후 null
        $used = [long]$cw.total_input_tokens
    }
} else {
    # 구버전 Claude Code 폴백: transcript 마지막 usage
    $tp = $j.transcript_path
    if ($tp -and (Test-Path -LiteralPath $tp)) {
        $lines = @(Get-TailLines $tp 80)
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            try { $o = $lines[$i] | ConvertFrom-Json } catch { continue }
            $u = $o.message.usage
            if ($u -and $null -ne $u.input_tokens) {
                $used = [long]$u.input_tokens + [long]$u.cache_read_input_tokens + [long]$u.cache_creation_input_tokens
                break
            }
        }
    }
    # model.id 기반 한도: Fable/Mythos/Opus 4.6+/1M 컨텍스트 변형 = 1M, 그 외 기본 200k.
    $mid = [string]$j.model.id
    if ($mid -match 'fable|mythos' -or $mid -match '\[1m\]' -or $mid -match 'opus-4-[6-9]') { $limit = 1000000 }
    else { $limit = 200000 }
    # 안전망: 1M 세션 신호(exceeds_200k_tokens) 또는 실측 200k 초과 시 1M 보정.
    if ($j.exceeds_200k_tokens -or $used -gt 200000) { $limit = 1000000 }
}
$pct = if ($limit -gt 0) { [math]::Round($used * 100.0 / $limit) } else { 0 }
$usedK = [math]::Round($used / 1000.0)
if ($limit -ge 1000000) {
    $m = [math]::Round($limit / 1000000.0, 1)
    $limitLabel = if ($m -eq [math]::Floor($m)) { "$([int]$m)M" } else { "${m}M" }
} else {
    $limitLabel = "$([math]::Round($limit / 1000.0))k"
}
$out = "ctx $pct% (${usedK}k/$limitLabel)"
if ($model) { $out += " | $model" }
# retrieval routing 표시: codemap 경유율(선언 기반, stop-check 파싱)이 주지표 + src 직접읽기 볼륨(백스톱).
# codemap N% = routed/(routed+full-scan). routed=codemap hit 선언, full-scan=codemap miss 선언. src=색인 미경유 직접 read 수.
# 선언 0 + src>0 = 미선언 직접읽기(풀스캔 의심) → src 노랑. ctx N%(ctxdb 매칭율)은 샘플 있을 때만 뒤에 붙임.
$e = [char]27; $G = "$e[32m"; $Y = "$e[33m"; $R = "$e[31m"; $D = "$e[90m"; $Z = "$e[0m"
$ch = 0; $cm = 0; $cd = 0; $xh = 0; $xm = 0
$retFile = ".ctxdb/.state/claude-retrieval-stats"
if (Test-Path -LiteralPath $retFile) {
    $rs = @(Get-Content -LiteralPath $retFile -ErrorAction SilentlyContinue)
    $ch = @($rs -eq 'cmap:hit').Count; $cm = @($rs -eq 'cmap:miss').Count; $cd = @($rs -eq 'cmap:direct').Count
    $xh = @($rs -eq 'ctx:hit').Count;  $xm = @($rs -eq 'ctx:miss').Count
}
$srcN = 0
$statsFile = ".ctxdb/.state/claude-read-stats"
if (Test-Path -LiteralPath $statsFile) { $srcN = @((Get-Content -LiteralPath $statsFile -ErrorAction SilentlyContinue) -eq 'src').Count }
# 응답 단위 통일 (v2.44 사후수정#2): 분모 = hit 선언(경유) + miss 선언 + 미선언 풀스캔(cmap:direct, stop-check 계수).
# 활용률 = 경유 / 전체 탐색 응답 -> 미선언 사각으로 인한 100% 뻥튀기 제거. 분모 3 미만은 소표본 스윙 방지로 % 숨김.
$fsN = $cm + $cd
$cdenom = $ch + $fsN
if (($cdenom + $srcN) -gt 0) {
    if ($cdenom -ge 3) {
        $rate = [int][math]::Floor($ch * 100.0 / $cdenom + 0.5)
        $rcol = if ($rate -ge 70) { $G } elseif ($rate -ge 40) { $Y } else { $R }
        $seg = "${D}codemap${Z} ${rcol}활용 ${rate}%${Z} ${D}(경유 $ch · 직행 $fsN)${Z}"
    } elseif ($cdenom -gt 0) {
        $seg = "${D}codemap${Z} 경유 $ch ${D}·${Z} 직행 $fsN"
    } else {
        $seg = "${D}codemap –${Z}"
    }
    if ($srcN -gt 0) {
        $seg += " ${D}·${Z} ${D}소스 읽기 $srcN${Z}"
    }
    if (($xh + $xm) -gt 0) {
        $xrate = [int][math]::Floor($xh * 100.0 / ($xh + $xm) + 0.5)
        $xcol = if ($xrate -ge 70) { $G } elseif ($xrate -ge 40) { $Y } else { $R }
        $seg += " ${D}· ctx${Z} ${xcol}${xrate}%${Z}"
    }
    $out += " | $([char]::ConvertFromUtf32(0x1F4E1)) $seg"
}
Write-Output $out

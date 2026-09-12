# Offline installer regression; fixtures/logs are retained in TEMP.
param([string]$BaselineRef = '3081267deaaab562783440ec8cd343f4a03511ca')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$setup = Join-Path $repo 'pawpad-setup.ps1'
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('pawpad-delegation-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
$checks = 0
function Assert-That([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "FAIL: $Label" }
    $script:checks++; Write-Output "PASS: $Label"
}
function Read-Text([string]$Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
function Assert-EqualText([string]$Actual, [string]$Expected, [string]$Label) {
    Assert-That (($Actual -replace "`r`n", "`n").Trim() -ceq ($Expected -replace "`r`n", "`n").Trim()) $Label
}
function Get-Manifest([string]$Root, [string[]]$Paths) {
    $result = @{}
    foreach ($rel in $Paths) {
        foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $Root $rel) -File -Recurse)) {
            $key = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
            $result[$key] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    return $result
}
function Assert-Manifest($Actual, $Expected, [string]$Label) {
    $different = @($Expected.Keys | Where-Object { -not $Actual.ContainsKey($_) -or $Actual[$_] -ne $Expected[$_] })
    Assert-That ($Actual.Count -eq $Expected.Count -and $different.Count -eq 0) "$Label ($($Expected.Count) files; differences: $($different -join ', '))"
}
function Invoke-Setup([string]$Script, [string]$Root, [string]$Tag, [switch]$Upgrade, [string]$Preset = 'full', [switch]$NoCodex) {
    if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root | Out-Null }
    $log = Join-Path $fixtureRoot "$Tag.log"
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-Stack', 'generic', '-Preset', $Preset, '-Lang', 'en', '-ShowLog')
    if ($Upgrade) { $params += '-Upgrade' }
    # v2.53: Codex surface is opt-in. Older baselines have no -WithCodex parameter.
    if (-not $NoCodex -and (Read-Text $Script) -match '\$WithCodex') { $params += '-WithCodex' }
    Push-Location -LiteralPath $Root
    try { & powershell @params *> $log; $code = $LASTEXITCODE } finally { Pop-Location }
    if ($code -ne 0) { throw "Installer exit $code; see $log" }
    if ((Get-Content -LiteralPath $log -Raw) -match '(?im)^\s*(FAILED|MERGE-FAIL)\b') { throw "Installer reported failure; see $log" }
}
function Get-CodexSection([string]$Text) {
    return [regex]::Match($Text, '(?ms)^## Codex [^\r\n]*\r?\n.*?(?=^## |\z)').Value
}
try {
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($setup, [ref]$tokens, [ref]$parseErrors)
    Assert-That ($parseErrors.Count -eq 0) 'Installer PowerShell syntax'
    $assignment = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$codexCodeDelegateSkill'
    }, $true)
    Assert-That ($null -ne $assignment) 'Codex template exists'
    $literal = $assignment.Right.Find({ param($node)
        $node -is [Management.Automation.Language.StringConstantExpressionAst]
    }, $true)
    Assert-That ($literal.StringConstantType -eq 'SingleQuotedHereString') 'Codex template is a literal (no execution)'
    $expectedSkill = $literal.Value
    $baselineLines = & git -c "safe.directory=$repo" -C $repo show "${BaselineRef}:pawpad-setup.ps1"
    if ($LASTEXITCODE -ne 0) { throw "Cannot read baseline $BaselineRef" }
    $baselineSetup = Join-Path $fixtureRoot 'baseline-setup.ps1'
    # Match checkout line endings before byte-comparing generated here-strings.
    $sourceNewline = if ((Read-Text $setup).Contains("`r`n")) { "`r`n" } else { "`n" }
    [IO.File]::WriteAllText($baselineSetup, ($baselineLines -join $sourceNewline).TrimStart([char]0xFEFF), (New-Object System.Text.UTF8Encoding $true))
    $oldRoot = Join-Path $fixtureRoot 'old/app'; $freshRoot = Join-Path $fixtureRoot 'fresh/app'
    Invoke-Setup $baselineSetup $oldRoot 'baseline'
    Invoke-Setup $setup $freshRoot 'fresh'
    $protectedPaths = @('CLAUDE.md', '.claude/skills', '.claude/hooks')
    Assert-Manifest (Get-Manifest $freshRoot $protectedPaths) (Get-Manifest $oldRoot $protectedPaths) 'Fresh install preserves Claude bytes'
    $skillRel = '.agents/skills/code-delegate/SKILL.md'
    Assert-EqualText (Read-Text (Join-Path $freshRoot $skillRel)) $expectedSkill 'Fresh install uses Codex template'
    $newMirrors = Get-Manifest $freshRoot @('.agents/skills'); $oldMirrors = Get-Manifest $oldRoot @('.agents/skills')
    $newMirrors.Remove($skillRel); $oldMirrors.Remove($skillRel)
    Assert-Manifest $newMirrors $oldMirrors 'Other Codex mirrors unchanged'
    $bytes = [IO.File]::ReadAllBytes((Join-Path $freshRoot $skillRel))
    Assert-That ($bytes[0] -eq 45 -and $bytes[1] -eq 45 -and $bytes[2] -eq 45) 'Skill frontmatter starts at byte zero'
    $agentsPath = Join-Path $oldRoot 'AGENTS.md'; $marker = 'stage2-user-section-preserved'
    [IO.File]::AppendAllText($agentsPath, "`n## User fixture`n$marker`n", $utf8)
    $memoryPath = Join-Path $oldRoot '.ctxdb/L2/stage2-user.md'
    [IO.File]::WriteAllText($memoryPath, 'User memory must survive upgrade.', $utf8)
    $memoryHash = (Get-FileHash -LiteralPath $memoryPath).Hash
    Invoke-Setup $setup $oldRoot 'upgrade' -Upgrade
    Assert-EqualText (Read-Text (Join-Path $oldRoot $skillRel)) $expectedSkill 'Upgrade replaces old delegate mirror'
    Assert-EqualText (Get-CodexSection (Read-Text $agentsPath)) (Get-CodexSection (Read-Text (Join-Path $freshRoot 'AGENTS.md'))) 'Upgrade installs current Codex rules'
    Assert-That ((Read-Text $agentsPath).Contains($marker)) 'Upgrade preserves user AGENTS section'
    Assert-That ((Get-FileHash -LiteralPath $memoryPath).Hash -eq $memoryHash) 'Upgrade preserves user memory'
    Assert-Manifest (Get-Manifest $oldRoot @('.claude/skills', '.claude/hooks')) (Get-Manifest $freshRoot @('.claude/skills', '.claude/hooks')) 'Upgrade preserves Claude skills and hooks'
    Assert-EqualText (Read-Text (Join-Path $oldRoot 'CLAUDE.md')) (Read-Text (Join-Path $freshRoot 'CLAUDE.md')) 'Upgrade preserves Claude instructions'
    $before = Get-CodexSection (Read-Text $agentsPath)
    Invoke-Setup $setup $oldRoot 'upgrade-repeat' -Upgrade
    Assert-EqualText (Get-CodexSection (Read-Text $agentsPath)) $before 'Repeated upgrade preserves Codex section'
    Assert-That ([regex]::Matches((Read-Text $agentsPath), '(?m)^## Codex ').Count -eq 1) 'No duplicate Codex section'
    Assert-EqualText (Read-Text (Join-Path $oldRoot $skillRel)) $expectedSkill 'Repeated upgrade retains Codex template'
    # v2.53: default install is Claude-only; the Codex surface needs -WithCodex.
    $claudeOnlyRoot = Join-Path $fixtureRoot 'claude-only/app'
    Invoke-Setup $setup $claudeOnlyRoot 'claude-only' -NoCodex
    Assert-That (-not (Test-Path (Join-Path $claudeOnlyRoot 'AGENTS.md'))) 'Default install omits AGENTS.md'
    Assert-That (-not (Test-Path (Join-Path $claudeOnlyRoot '.agents'))) 'Default install omits Codex skill mirror'
    Assert-That (-not (Test-Path (Join-Path $claudeOnlyRoot '.codex'))) 'Default install omits Codex adapter'
    Assert-That (Test-Path (Join-Path $claudeOnlyRoot 'CLAUDE.md')) 'Default install still writes CLAUDE.md'
    $claudePaths = @('CLAUDE.md', '.claude/skills', '.claude/hooks')
    Assert-Manifest (Get-Manifest $claudeOnlyRoot $claudePaths) (Get-Manifest $freshRoot $claudePaths) 'Claude-only install preserves Claude bytes'
    # An existing Codex surface keeps being updated even without -WithCodex.
    [IO.File]::WriteAllText((Join-Path $oldRoot $skillRel), 'stale mirror', $utf8)
    Invoke-Setup $setup $oldRoot 'upgrade-detect' -Upgrade -NoCodex
    Assert-EqualText (Read-Text (Join-Path $oldRoot $skillRel)) $expectedSkill 'Existing Codex surface still refreshed without -WithCodex'
    $leanRoot = Join-Path $fixtureRoot 'lean/app'
    Invoke-Setup $setup $leanRoot 'lean' -Preset 'lean'
    Assert-That (-not (Test-Path (Join-Path $leanRoot $skillRel))) 'Lean preset excludes code-delegate'
    Assert-EqualText (Read-Text (Join-Path $repo $skillRel)) $expectedSkill 'Checked-in skill matches generator'
    Write-Output "Result: $checks checks passed. Fixtures: $fixtureRoot"
} catch { Write-Error "$_`nFixtures: $fixtureRoot" -ErrorAction Continue; exit 1 }

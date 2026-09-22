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
function Invoke-Setup([string]$Script, [string]$Root, [string]$Tag, [switch]$Upgrade, [string]$Preset = 'full', [switch]$NoCodex, [string]$CodexPreset = '', [switch]$NoPreset, [string]$BundlesCsv = '', [string]$CodexBundlesCsv = '') {
    if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root | Out-Null }
    $log = Join-Path $fixtureRoot "$Tag.log"
    $params = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-Stack', 'generic', '-Lang', 'en', '-ShowLog')
    # v2.54: -NoPreset omits the bundle args entirely so the recorded selection in pawpad-config.json is exercised.
    if (-not $NoPreset) { $params += @('-Preset', $Preset) }
    if ($CodexPreset) { $params += @('-CodexPreset', $CodexPreset) }
    if ($BundlesCsv) { $params += @('-Bundles', $BundlesCsv) }
    if ($CodexBundlesCsv) { $params += @('-CodexBundles', $CodexBundlesCsv) }
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
    # Exercise the actual installer function without regenerating user config first.
    $bundleFunction = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-BundleRecord'
    }, $true)
    & {
        . ([scriptblock]::Create($bundleFunction.Extent.Text))
        function Write-InstallLog { param($Message, $Color, [switch]$Always) }
        $recordRoot = Join-Path $fixtureRoot 'bundle-record'
        New-Item -ItemType Directory -Path (Join-Path $recordRoot '.claude') | Out-Null
        $recordPath = Join-Path $recordRoot '.claude/pawpad-config.json'
        $cases = @(
            @{ Name = 'empty object'; Json = '{}' },
            @{ Name = 'compact JSON'; Json = '{"hooks":{"enabled":false},"bundles":{"claude":["qa"],"codex":["qa"]},"user":{"nested":{"level":{"value":"preserved"}}}}' },
            @{ Name = 'nested bundles'; Json = "{`r`n  `"bundles`": {`r`n    `"custom`": {`r`n      `"nested`": true`r`n    },`r`n    `"claude`": [`"qa`"]`r`n  },`r`n  `"user`": {`"nested`": {`"level`": {`"value`": `"preserved`"}}}`r`n}" }
        )
        Push-Location -LiteralPath $recordRoot
        try {
            foreach ($case in $cases) {
                [IO.File]::WriteAllText($recordPath, $case.Json, $utf8)
                $script:failed = 0
                Update-BundleRecord @('review', 'prd') @()
                $recordText = Read-Text $recordPath
                $record = ConvertFrom-Json -InputObject $recordText -ErrorAction Stop
                Assert-That ($script:failed -eq 0 -and ($record.bundles.claude -join ',') -eq 'prd,review' -and @($record.bundles.codex).Count -eq 0) "$($case.Name): valid JSON and selected bundles"
                $original = ConvertFrom-Json -InputObject $case.Json
                $record.PSObject.Properties.Remove('bundles')
                $original.PSObject.Properties.Remove('bundles')
                Assert-EqualText (ConvertTo-Json -InputObject $record -Depth 100 -Compress) (ConvertTo-Json -InputObject $original -Depth 100 -Compress) "$($case.Name): unrelated properties preserved"
                $recordBytes = [IO.File]::ReadAllBytes($recordPath)
                Assert-That ($recordBytes[0] -eq 123 -and [regex]::Matches($recordText, '"bundles"\s*:').Count -eq 1) "$($case.Name): no BOM or duplicate bundles key"
            }
            [IO.File]::WriteAllText($recordPath, '{"broken":', $utf8)
            $script:failed = 0
            Update-BundleRecord @('prd') @()
            Assert-That ($script:failed -eq 1 -and (Read-Text $recordPath) -ceq '{"broken":') 'Invalid JSON is preserved and counted as an install failure'
        } finally { Pop-Location }
    }
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
    # v2.54: Codex-only bundle axis. Claude stays full while the Codex surface is narrowed.
    function Get-SkillNames([string]$Root, [string]$Rel) {
        return @(Get-ChildItem -LiteralPath (Join-Path $Root $Rel) -Directory -EA SilentlyContinue | ForEach-Object { $_.Name } | Sort-Object)
    }
    $asymRoot = Join-Path $fixtureRoot 'asym/app'
    Invoke-Setup $setup $asymRoot 'asym' -Preset 'full' -CodexPreset 'lean'
    $asymClaude = Get-SkillNames $asymRoot '.claude/skills'
    $asymCodex = Get-SkillNames $asymRoot '.agents/skills'
    Assert-That ($asymClaude.Count -eq 22 -and $asymCodex.Count -eq 12) "Codex axis narrows only the mirror (claude=$($asymClaude.Count) codex=$($asymCodex.Count))"
    Assert-That (@($asymCodex | Where-Object { $asymClaude -notcontains $_ }).Count -eq 0) 'Codex mirror stays a subset of the Claude install'
    $asymCfg = (Read-Text (Join-Path $asymRoot '.codex/config.json')) | ConvertFrom-Json
    Assert-That (@($asymCfg.skills).Count -eq 12) "config.json skills follow the Codex axis ($(@($asymCfg.skills).Count))"
    Assert-That (@(@($asymCfg.skills) | Where-Object { $asymCodex -notcontains $_ }).Count -eq 0) 'config.json lists no skill missing from the mirror'
    # 'review/trust' is the Codex /hooks instruction, not the review skill; strip it before scanning for skill names.
    $asymAgents = (Read-Text (Join-Path $asymRoot 'AGENTS.md')) -replace 'review/trust', ''
    $codexDropped = @($asymClaude | Where-Object { $asymCodex -notcontains $_ })
    Assert-That (@($codexDropped | Where-Object { $asymAgents -match ('(?<![A-Za-z0-9-])' + [regex]::Escape($_) + '(?![A-Za-z0-9-])') }).Count -eq 0) 'AGENTS.md drops every Codex-excluded skill name'
    $asymManifest = Read-Text (Join-Path $asymRoot '.agents/SKILLS_MANIFEST.md')
    Assert-That ([regex]::Matches($asymManifest, '(?m)^\|\s*\*\*').Count -eq 12) 'Codex manifest lists only the Codex skills'
    $claudeSurface = @('CLAUDE.md', '.claude/skills', '.claude/hooks', '.claude/HYBRID.md', '.claude/SKILLS_MANIFEST.md')
    Assert-Manifest (Get-Manifest $asymRoot $claudeSurface) (Get-Manifest $freshRoot $claudeSurface) 'Narrowing the Codex axis leaves Claude bytes untouched'
    # The Codex axis cannot exceed the Claude install (mirror source is .claude/skills).
    $clampRoot = Join-Path $fixtureRoot 'clamp/app'
    Invoke-Setup $setup $clampRoot 'clamp' -Preset 'lean' -CodexPreset 'full'
    Assert-That ((Get-SkillNames $clampRoot '.claude/skills').Count -eq 12 -and (Get-SkillNames $clampRoot '.agents/skills').Count -eq 12) 'Codex axis is clamped to the Claude install set'
    # The selection is recorded, so an upgrade without bundle args keeps it instead of restoring full.
    Invoke-Setup $setup $asymRoot 'asym-upgrade' -Upgrade -NoPreset
    Assert-That ((Get-SkillNames $asymRoot '.claude/skills').Count -eq 22 -and (Get-SkillNames $asymRoot '.agents/skills').Count -eq 12) 'Upgrade without bundle args reuses the recorded selection'
    $asymCfgJson = (Read-Text (Join-Path $asymRoot '.claude/pawpad-config.json')) | ConvertFrom-Json
    Assert-That (@($asymCfgJson.bundles.claude).Count -eq 5 -and @($asymCfgJson.bundles.codex).Count -eq 0) 'pawpad-config.json records both axes'
    # Comma-form bundle args: PowerShell parses `-Bundles prd,review` as an array and hands the
    # [string] parameter a space-joined value, so splitting on ',' alone collapsed it to Core (latent since v2.39).
    $csvRoot = Join-Path $fixtureRoot 'csv/app'
    Invoke-Setup $setup $csvRoot 'csv' -NoPreset -BundlesCsv 'prd,review' -CodexBundlesCsv 'prd'
    Assert-That ((Get-SkillNames $csvRoot '.claude/skills').Count -eq 17) "Comma-form -Bundles keeps the named bundles ($((Get-SkillNames $csvRoot '.claude/skills').Count))"
    Assert-That ((Get-SkillNames $csvRoot '.agents/skills').Count -eq 16) "Comma-form -CodexBundles applies to the mirror ($((Get-SkillNames $csvRoot '.agents/skills').Count))"
    Assert-EqualText (Read-Text (Join-Path $repo $skillRel)) $expectedSkill 'Checked-in skill matches generator'
    Write-Output "Result: $checks checks passed. Fixtures: $fixtureRoot"
} catch { Write-Error "$_`nFixtures: $fixtureRoot" -ErrorAction Continue; exit 1 }

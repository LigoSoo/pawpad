param(
    [Parameter(Mandatory = $true)]
    [string]$HookName
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $hookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent (Split-Path -Parent $hookDir)
    $hookPath = Join-Path $hookDir $HookName

    if (-not (Test-Path -LiteralPath $hookPath)) {
        exit 0
    }

    Push-Location $repoRoot
    try {
        & $hookPath
        $code = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }
        exit $code
    } finally {
        Pop-Location
    }
} catch {
    exit 0
}

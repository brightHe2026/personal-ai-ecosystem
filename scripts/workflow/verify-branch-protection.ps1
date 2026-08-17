# Read-only Branch Protection verifier for main (TASK-005C-F / D-009 / C-004 / C-005).
# Always Run candidate. Does not PUT protection, merge, push main, or write state.json.
param(
    [string]$ProtectionJsonPath = '',
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$verdict = $null
if (-not [string]::IsNullOrWhiteSpace($ProtectionJsonPath)) {
    if (-not (Test-Path -LiteralPath $ProtectionJsonPath)) {
        throw "Refused: protection JSON path not found: $ProtectionJsonPath"
    }
    $raw = Get-Content -LiteralPath $ProtectionJsonPath -Raw -Encoding UTF8
    $verdict = ConvertTo-BranchProtectionVerdictFromJson -Json $raw
}
else {
    $got = Get-MainBranchProtection
    $verdict = ConvertTo-BranchProtectionVerdict -Protection $got.Protection
}

Write-Host "verdict=$($verdict.verdict)"
foreach ($r in @($verdict.reasons)) {
    Write-Host "reason=$r"
}

if ($Json) {
    Write-Host ($verdict | ConvertTo-Json -Depth 6 -Compress)
}

switch ([string]$verdict.verdict) {
    'compliant' { exit 0 }
    'not-protected' { exit 2 }
    default { exit 1 }
}

# Human-gated classic Branch Protection apply helper (TASK-005C-F / D-007 / D-008 / D-009).
# Default: print the PUT payload and refuse to mutate GitHub.
# Mutates only with -Apply after Gate 1. Never Always Run. Never from CI or bootstrap.
param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

if ($env:GITHUB_ACTIONS -eq 'true') {
    throw 'Refused: apply-branch-protection.ps1 must not run from GitHub Actions / CI.'
}

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
Assert-PlanApproved -State $state -RepoRoot $root

$payload = Get-BranchProtectionApplyPayloadJson
Write-Host $payload
Write-Host 'Payload matches D-007/D-008: required check ci-gate only, strict, PR required, approving review count 0, force/delete disallowed, enforce_admins false.'

if (-not $Apply) {
    Write-Host 'Refused to mutate GitHub. Re-run with -Apply after Gate 1 (Human-gated). Never Always Run. Never from bootstrap/CI/archive.'
    exit 0
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("branch-protection-" + [guid]::NewGuid().ToString('N') + '.json')
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
try {
    [System.IO.File]::WriteAllText($tmp, $payload.Trim() + [Environment]::NewLine, $utf8NoBom)
    $putArgs = @(
        'api',
        '--method', 'PUT',
        'repos/:owner/:repo/branches/main/protection',
        '--input', $tmp
    )
    Assert-MergeForbidden -CommandParts $putArgs
    $out = Invoke-Gh -GhArgs $putArgs
    Write-Host $out
}
finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

$got = Get-MainBranchProtection -RepoRoot $root
$verdict = ConvertTo-BranchProtectionVerdict -Protection $got.Protection
Write-Host "verdict=$($verdict.verdict)"
foreach ($r in @($verdict.reasons)) {
    Write-Host "reason=$r"
}
if ([string]$verdict.verdict -ne 'compliant') {
    throw "Refused: protection PUT completed but verifier is not compliant (C-004). Do not silently change required_approving_review_count to 1."
}
Write-Host 'apply-branch-protection: PUT completed and verifier is compliant.'

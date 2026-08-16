# Prepare TASK archive on main after Human merge. Does not push. Does not merge.
# N-002: durable ci_status comes from a live GitHub Checks query, not stale runtime.json.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$branch = Get-CurrentBranch -RepoRoot $root
Assert-OnMain -Branch $branch

# Independent D-001/finalize facts. Does not read AGENT_D001_ARCHIVE.
$facts = Assert-D001ArchivePreconditions -RepoRoot $root

if ($DryRun) {
    Write-Host "DRY RUN: would archive $($facts.TaskId) PR #$($facts.PrNumber) durable ci_status=$($facts.DurableCi) ci_gate=$($facts.CiGate)"
    Write-Host 'Live GitHub Checks used (N-002). Would not push. Would not gh pr merge.'
    exit 0
}

$dest = Invoke-FinalizePrepApply -Facts $facts -RepoRoot $root

$stateAfter = Get-StateObject -RepoRoot $root
Write-DerivedHandoff `
    -State $stateAfter `
    -RepoRoot $root `
    -Notes 'finalize-prep applied on main after MERGED + live Checks (N-002). This script does not push. Next: archive-push.ps1 which independently re-verifies all D-001 preconditions. AGENT_D001_ARCHIVE=1 is not authorization. Handoff derived (C-001).' | Out-Null

Write-Host "Archived $($facts.TaskId) -> $dest"
Write-Host "Durable state: status=completed pr_url=$($facts.View.url) ci_status=$($facts.DurableCi) (from live Checks, N-002)"
Write-Host 'This script does not push. Next: pwsh -File scripts/workflow/archive-push.ps1'
Write-Host 'AGENT_D001_ARCHIVE=1 is not push authorization. Do not gh pr merge.'

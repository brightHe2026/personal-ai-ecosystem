# Coding → in_review (C-002). Sets review_round 0→1 only; later re-entry does not increment.
# Regenerates derived handoff (C-001). Does not merge. Does not write .agent/reviews/.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
Assert-PlanApproved -State $state -RepoRoot $root

if ([string]$state.status -ne 'coding') {
    throw "Refused: enter-review requires status=coding (got $($state.status))."
}
$taskId = [string]$state.active_task
if (-not $taskId) { throw 'Refused: active_task is null.' }
$report = Get-OptionalReportRelativePath -TaskId $taskId -RepoRoot $root
if ($report -eq '(none)') {
    throw "Refused: missing .agent/reports/$taskId-report.md before in_review."
}

$before = 0
try { $before = [int]$state.review_round } catch { $before = 0 }
$state = Enter-InReviewState -State $state
$after = [int]$state.review_round

if ($DryRun) {
    Write-Host "DRY RUN: would set status=in_review review_round $before -> $after (C-002)."
    exit 0
}

Save-StateObject -State $state -RepoRoot $root | Out-Null
$path = Write-DerivedHandoff `
    -State $state `
    -RepoRoot $root `
    -Notes "Coding entered in_review (C-002). Human spawn: ROLE=review-agent or @handoff. Independent Review is a separate session (D-003). Do not self-review."

Write-Host "enter-review: status=in_review task=$taskId review_round=$after"
Write-Host "handoff: $path next_actor=review-agent next_action=independent-review"
Write-Host 'STOP for Independent Review. Human is spawn-only (C-003).'

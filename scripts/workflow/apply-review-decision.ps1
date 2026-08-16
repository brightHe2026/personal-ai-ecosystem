# Review Agent: apply decision from review-round-N.md (C-001/C-002).
# reject → coding, review_round += 1 once, required_fixes_file = the file just written.
# approve → git_ready, review_round unchanged.
# Does not implement fixes. Does not merge. Does not commit.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
if ([string]$state.status -ne 'in_review') {
    throw "Refused: apply-review-decision requires status=in_review (got $($state.status))."
}
$taskId = [string]$state.active_task
if (-not $taskId) { throw 'Refused: active_task is null.' }
$round = 0
try { $round = [int]$state.review_round } catch { $round = 0 }
if ($round -lt 1) {
    throw 'Refused: review_round must be >= 1 during in_review (C-002).'
}

$reviewPath = Get-ReviewRoundFile -TaskId $taskId -Round $round -RepoRoot $root
if (-not (Test-Path -LiteralPath $reviewPath)) {
    throw "Refused: missing review file for the round being reviewed: $reviewPath"
}
$text = Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8
$decision = Get-ReviewDecisionFromText -Raw $text
if ($decision -ne 'approve' -and $decision -ne 'reject') {
    throw "Refused: review file has no decision approve|reject (C-001)."
}

$before = $round
if ($decision -eq 'reject') {
    $state = Apply-ReviewRejectState -State $state
}
else {
    $state = Apply-ReviewApproveState -State $state
}
$after = [int]$state.review_round

if ($DryRun) {
    Write-Host "DRY RUN: decision=$decision status=$($state.status) review_round $before -> $after"
    exit 0
}

Save-StateObject -State $state -RepoRoot $root | Out-Null
$rel = Get-RelativeRepoPath -FullPath $reviewPath -RepoRoot $root
$notes = "Independent Review $decision (round $before). Coding must read $rel. Human returns with at most: continue from handoff (C-003). Review Agent does not implement fixes."
if ($decision -eq 'approve') {
    $notes = "Independent Review approve (round $before). Same Coding session: open-pr.ps1 then observe-ci.ps1 -Wait. No new Human Git Ready essay. Do not gh pr merge."
}
$path = Write-DerivedHandoff -State $state -RepoRoot $root -Notes $notes
Write-Host "apply-review-decision: decision=$decision status=$($state.status) review_round=$after"
Write-Host "handoff: $path"
Write-Host 'Review session STOP. Do not implement. Do not merge. Do not push main.'

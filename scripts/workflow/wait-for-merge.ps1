# Poll GitHub until the TASK PR is MERGED. Does not merge. Does not push.
# Timeout: STOP for Human Gate 2. Do not forge MERGED.
param(
    [switch]$DryRun,
    [int]$PrNumber = 0,
    [int]$TimeoutSeconds = 1800,
    [int]$PollSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
$runtime = Read-RuntimeObject -RepoRoot $root
$taskId = [string]$state.active_task
if (-not $taskId -and $runtime) { $taskId = [string]$runtime.task_id }
if (-not $taskId) { throw 'Cannot wait-for-merge: active_task and runtime.task_id are empty.' }

$pr = $PrNumber
if ($pr -le 0 -and $runtime -and $runtime.pr_number) {
    $pr = [int]$runtime.pr_number
}
if ($pr -le 0) {
    throw 'Refused: no PR number. Run open-pr.ps1 after Review approve, then wait-for-merge.'
}

if ($PollSeconds -lt 5) { $PollSeconds = 5 }
if ($TimeoutSeconds -lt $PollSeconds) { $TimeoutSeconds = $PollSeconds }

$view = Get-LivePrView -PrNumber $pr
if ($DryRun) {
    Write-Host "DRY RUN PR #$pr state=$($view.state) mergedAt=$($view.mergedAt)"
    exit 0
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$merged = ($view.state -eq 'MERGED' -and $view.mergedAt)
while (-not $merged) {
    if ((Get-Date) -ge $deadline) {
        Write-DerivedHandoff `
            -State $state `
            -RepoRoot $root `
            -Notes "wait-for-merge timed out after ${TimeoutSeconds}s. Last GitHub state=$($view.state). Do not forge MERGED. Human Gate 2 remains. Re-run wait-for-merge.ps1 after merge." | Out-Null
        throw "Timed out waiting for PR #$pr MERGED after ${TimeoutSeconds}s (last state=$($view.state)). STOP for Human Gate 2. Do not forge MERGED."
    }
    Write-Host "wait-for-merge: PR #$pr state=$($view.state) (not MERGED). Sleeping ${PollSeconds}s..."
    Start-Sleep -Seconds $PollSeconds
    $view = Get-LivePrView -PrNumber $pr
    $merged = ($view.state -eq 'MERGED' -and $view.mergedAt)
}

$runtimeObj = New-RuntimeObject `
    -TaskId $taskId `
    -PrUrl $view.url `
    -PrNumber ([int]$view.number) `
    -HeadSha $view.headRefOid `
    -CiGate $(if ($runtime -and $runtime.ci_gate) { [string]$runtime.ci_gate } else { 'n/a' }) `
    -ProtocolStatus 'awaiting_merge' `
    -ProtocolCiStatus $(if ($runtime -and $runtime.protocol_ci_status) { [string]$runtime.protocol_ci_status } else { 'n/a' }) `
    -CiRequired ([bool]$state.ci_required) `
    -Merged $true `
    -Source 'github-pr'

Write-RuntimeObject -Runtime $runtimeObj -RepoRoot $root | Out-Null

Write-DerivedHandoff `
    -State $state `
    -RepoRoot $root `
    -Notes 'GitHub reports MERGED. Next: finalize-prep.ps1 then archive-push.ps1 (D-001 independent checks). AGENT_D001_ARCHIVE=1 is not authorization. Do not gh pr merge. Handoff derived (C-001).' | Out-Null

Write-Host "PR #$pr MERGED at $($view.mergedAt)"
Write-Host 'Next: pwsh -File scripts/workflow/finalize-prep.ps1'
Write-Host 'Then: pwsh -File scripts/workflow/archive-push.ps1'
Write-Host 'Do not gh pr merge. AGENT_D001_ARCHIVE=1 is not push authorization.'

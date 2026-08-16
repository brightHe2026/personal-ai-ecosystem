# Observe GitHub Checks and write gitignored .agent/runtime.json.
# Only real ci-gate PASS may move a ci_required TASK to awaiting_merge.
param(
    [switch]$DryRun,
    [int]$PrNumber = 0,
    [switch]$Wait,
    [int]$TimeoutSeconds = 600,
    [int]$PollSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
$runtime = Read-RuntimeObject -RepoRoot $root
$ciRequired = [bool]$state.ci_required
$taskId = [string]$state.active_task
if (-not $taskId -and $runtime) { $taskId = [string]$runtime.task_id }
if (-not $taskId) { throw 'Cannot observe CI: active_task and runtime.task_id are empty.' }

$pr = $PrNumber
if ($pr -le 0 -and $runtime -and $runtime.pr_number) {
    $pr = [int]$runtime.pr_number
}

Push-Location $root
try {
    if ($pr -le 0) {
        try {
        $view = (ConvertFrom-GhJson (Invoke-Gh -GhArgs @('pr', 'view', '--json', 'number,url,state,headRefOid'))) | Select-Object -First 1
        $pr = [int]$view.number
        }
        catch {
            throw 'Refused: no PR found for this branch and runtime.json has no pr_number. Run open-pr.ps1 after Review approve.'
        }
    }

    $view = (ConvertFrom-GhJson (Invoke-Gh -GhArgs @('pr', 'view', "$pr", '--json', 'number,url,state,headRefOid,headRefName'))) | Select-Object -First 1
    $checks = @(ConvertFrom-GhJson (Invoke-Gh -GhArgs @('pr', 'checks', "$pr", '--json', 'name,state,bucket')))
}
finally {
    Pop-Location
}

$ciGate = Get-CiGateFact -Checks $checks
$protocol = Resolve-ProtocolFromCiGate -CiGate $ciGate -CiRequired $ciRequired
Assert-AwaitingMergeLegal -ProtocolStatus $protocol.protocol_status -CiGate $ciGate -CiRequired $ciRequired -ProtocolCiStatus $protocol.protocol_ci_status

if ($Wait -and -not $DryRun) {
    if ($PollSeconds -lt 5) { $PollSeconds = 5 }
    if ($TimeoutSeconds -lt $PollSeconds) { $TimeoutSeconds = $PollSeconds }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($ciGate -eq 'pending') {
        if ((Get-Date) -ge $deadline) {
            Write-Host "observe-ci -Wait timed out after ${TimeoutSeconds}s with ci_gate=pending. STOP for Human Gate 2. Do not forge passed or failed."
            break
        }
        Write-Host "observe-ci -Wait: ci_gate=pending. Sleeping ${PollSeconds}s..."
        Start-Sleep -Seconds $PollSeconds
        Push-Location $root
        try {
            $view = (ConvertFrom-GhJson (Invoke-Gh -GhArgs @('pr', 'view', "$pr", '--json', 'number,url,state,headRefOid,headRefName'))) | Select-Object -First 1
            $checks = @(ConvertFrom-GhJson (Invoke-Gh -GhArgs @('pr', 'checks', "$pr", '--json', 'name,state,bucket')))
        }
        finally {
            Pop-Location
        }
        $ciGate = Get-CiGateFact -Checks $checks
        $protocol = Resolve-ProtocolFromCiGate -CiGate $ciGate -CiRequired $ciRequired
        Assert-AwaitingMergeLegal -ProtocolStatus $protocol.protocol_status -CiGate $ciGate -CiRequired $ciRequired -ProtocolCiStatus $protocol.protocol_ci_status
    }
}

if ($DryRun) {
    Write-Host "DRY RUN PR #$pr ci_gate=$ciGate protocol_status=$($protocol.protocol_status) protocol_ci_status=$($protocol.protocol_ci_status)"
    exit 0
}

$newRuntime = New-RuntimeObject `
    -TaskId $taskId `
    -PrUrl $view.url `
    -PrNumber ([int]$view.number) `
    -HeadSha $view.headRefOid `
    -CiGate $ciGate `
    -ProtocolStatus $protocol.protocol_status `
    -ProtocolCiStatus $protocol.protocol_ci_status `
    -CiRequired $ciRequired `
    -Merged ($view.state -eq 'MERGED') `
    -Source 'github-checks'

$path = Write-RuntimeObject -Runtime $newRuntime -RepoRoot $root

$timedOutPending = $Wait -and $ciGate -eq 'pending'
$nextActor = 'human'
$nextAction = 'merge-main'
$notes = 'CI observed. Human Gate 2 is merge. Do not gh pr merge. Do not forge passed.'
if ($ciRequired -and $ciGate -eq 'success') {
    $nextActor = 'human'
    $nextAction = 'merge-main'
    $notes = 'ci-gate success. Live awaiting_merge/passed. Next: Human merges, then wait-for-merge.ps1.'
}
elseif ($ciRequired -and $ciGate -eq 'failure') {
    $nextActor = 'coding-agent'
    $nextAction = 'ci-recovery'
    $notes = 'ci-gate failed. Stay ci_running. See ci-gate.md recovery. Never forge passed or awaiting_merge.'
}
elseif ($timedOutPending) {
    $nextActor = 'human'
    $nextAction = 'merge-main'
    $notes = 'observe-ci -Wait timed out still pending. Last fact kept as pending. Do not forge passed or failed. STOP for Human Gate 2 or re-run observe-ci -Wait.'
}
elseif (-not $ciRequired) {
    $nextActor = 'human'
    $nextAction = 'merge-main'
    $notes = 'ci_required=no: protocol n/a. Next: Human merge, then wait-for-merge.ps1. Same Coding session may poll merge without a new prompt.'
}

Write-Handoff `
    -TaskId $taskId `
    -Status $newRuntime.protocol_status `
    -PlanApproved (Test-PlanApprovedFlag -State $state) `
    -NextActor $nextActor `
    -NextAction $nextAction `
    -Notes $notes `
    -RepoRoot $root | Out-Null

Write-Host "Wrote live overlay $path"
Write-Host "PR $($newRuntime.pr_url) sha=$($newRuntime.head_sha)"
Write-Host "ci_gate=$ciGate (GitHub Checks SoT)"
Write-Host "protocol_status=$($newRuntime.protocol_status) protocol_ci_status=$($newRuntime.protocol_ci_status)"
if ($ciRequired -and $ciGate -ne 'success') {
    Write-Host 'Not awaiting_merge: ci-gate is not green. See ci-gate.md recovery. Never forge passed.'
}
if (-not $ciRequired) {
    Write-Host 'ci_required=no: protocol ci_status stays n/a even if ci-gate is green.'
}
if ($timedOutPending) {
    Write-Host 'Timeout: ci_gate left as pending. Do not forge passed or failed.'
}
Write-Host 'Do not commit runtime.json. Do not gh pr merge. Human merges main.'
if ($newRuntime.protocol_status -eq 'awaiting_merge') {
    Write-Host 'Next: pwsh -File scripts/workflow/wait-for-merge.ps1'
}

# Write gitignored .agent/handoff.md (and runtime next_* if overlay exists).
param(
    [Parameter(Mandatory = $true)][string]$NextActor,
    [Parameter(Mandatory = $true)][string]$NextAction,
    [string]$Notes = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$state = Get-StateObject -RepoRoot $root
$taskId = [string]$state.active_task
if (-not $taskId) { $taskId = [string]$state.last_completed_task }
if (-not $taskId) { throw 'Refused: no task_id for handoff.' }

$path = Write-Handoff `
    -TaskId $taskId `
    -Status ([string]$state.status) `
    -PlanApproved (Test-PlanApprovedFlag -State $state) `
    -NextActor $NextActor `
    -NextAction $NextAction `
    -Notes $Notes `
    -RepoRoot $root

Write-Host "Wrote $path next_actor=$NextActor next_action=$NextAction"

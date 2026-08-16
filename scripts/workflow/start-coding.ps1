# Gate 1 PRIMARY enforcement: refuse to start implementation unless plan_approved is true.
# Approval authority is Human/Planner only. This script persists coding status after that approval.
# open-pr.ps1 plan_approved check is defense-in-depth only — not a substitute for this gate.
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

$taskId = [string]$state.active_task
if (-not $taskId) {
    throw 'Refused: state.json active_task is null. start-coding cannot begin implementation.'
}

$legal = @('specified', 'coding')
if ($legal -notcontains [string]$state.status) {
    throw "Refused: start-coding allows status specified or coding (idempotent). Current status=$($state.status)."
}

if ($DryRun) {
    Write-Host "DRY RUN: Gate 1 PRIMARY passed (plan_approved=true). Would set status=coding for $taskId."
    exit 0
}

$state.status = 'coding'
$state.agents.cursor.status = 'working'
$state.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
Save-StateObject -State $state -RepoRoot $root | Out-Null

$handoff = Write-Handoff `
    -TaskId $taskId `
    -Status 'coding' `
    -PlanApproved $true `
    -NextActor 'coding-agent' `
    -NextAction 'implement' `
    -Gate1Decision 'APPROVED' `
    -ApprovalAuthority 'Human/Planner' `
    -Reads @(
        ".agent/tasks/active/$taskId-*.md",
        '.agent/state.json',
        '.agent/workflows/task-lifecycle.md'
    ) `
    -Notes 'Gate 1 PRIMARY (start-coding.ps1) passed. Coding Agent may implement the approved plan. Do not infer new approvals from chat. Independent Review remains a separate session.' `
    -RepoRoot $root

Write-Host "start-coding: status=coding task=$taskId plan_approved=true"
Write-Host "handoff: $handoff"
Write-Host 'PRIMARY Gate 1 enforcement passed. open-pr plan_approved check is defense-in-depth only.'

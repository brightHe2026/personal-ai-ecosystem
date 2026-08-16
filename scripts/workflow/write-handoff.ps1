# Write gitignored .agent/handoff.md from authoritative state/review (C-001).
# Does not accept caller next_actor/next_action — those are derived, never guessed.
param(
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

$path = Write-DerivedHandoff -State $state -Notes $Notes -RepoRoot $root
$facts = Get-DerivedHandoffFacts -State $state -RepoRoot $root
Write-Host "Wrote $path next_actor=$($facts.NextActor) next_action=$($facts.NextAction) (derived C-001)"

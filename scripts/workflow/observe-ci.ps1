# Observe GitHub Checks and write gitignored .agent/runtime.json.
# Only real ci-gate PASS may move a ci_required TASK to awaiting_merge.
param(
    [switch]$DryRun,
    [int]$PrNumber = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden -CommandParts $args

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
            $view = (Invoke-Gh -GhArgs @('pr', 'view', '--json', 'number,url,state,headRefOid')) | ConvertFrom-Json
            $pr = [int]$view.number
        }
        catch {
            throw 'Refused: no PR found for this branch and runtime.json has no pr_number. Run open-pr.ps1 after Review approve.'
        }
    }

    $view = (Invoke-Gh -GhArgs @('pr', 'view', "$pr", '--json', 'number,url,state,headRefOid,headRefName')) | ConvertFrom-Json
    $checksJson = Invoke-Gh -GhArgs @('pr', 'checks', "$pr", '--json', 'name,state,bucket')
    $checks = @($checksJson | ConvertFrom-Json)
}
finally {
    Pop-Location
}

$ciGate = Get-CiGateFact -Checks $checks
$protocol = Resolve-ProtocolFromCiGate -CiGate $ciGate -CiRequired $ciRequired
Assert-AwaitingMergeLegal -ProtocolStatus $protocol.protocol_status -CiGate $ciGate -CiRequired $ciRequired -ProtocolCiStatus $protocol.protocol_ci_status

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
Write-Host 'Do not commit runtime.json. Do not gh pr merge. Human merges main.'

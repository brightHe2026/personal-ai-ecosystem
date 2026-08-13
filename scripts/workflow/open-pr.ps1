# Open (or reuse) the TASK PR after Independent Review approve.
# Writes gitignored .agent/runtime.json. Does not merge. Does not push main.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden -CommandParts $args

$root = Get-RepoRoot
$branch = Get-CurrentBranch -RepoRoot $root
Assert-TaskBranch -Branch $branch

$state = Get-StateObject -RepoRoot $root
if (-not $state.active_task) {
    throw 'Refused: state.json active_task is null.'
}
$taskId = [string]$state.active_task
$ciRequired = [bool]$state.ci_required

if ($state.status -ne 'git_ready' -and $state.status -ne 'ci_running' -and $state.status -ne 'awaiting_merge') {
    throw "Refused: open-pr requires status git_ready (or later CI states). Current status=$($state.status)."
}

$review = Assert-ReviewApproved -TaskId $taskId -RepoRoot $root
$taskFile = Find-TaskFile -TaskId $taskId -RepoRoot $root
$reportFile = Find-ReportFile -TaskId $taskId -RepoRoot $root
$taskRel = Get-RelativeRepoPath -FullPath $taskFile -RepoRoot $root
$reportRel = Get-RelativeRepoPath -FullPath $reportFile -RepoRoot $root
$reviewRel = Get-RelativeRepoPath -FullPath $review.Path -RepoRoot $root

if ($DryRun) {
    Write-Host "DRY RUN: would open/reuse PR for $taskId on $branch"
    Write-Host "TASK: $taskRel"
    Write-Host "Report: $reportRel"
    Write-Host "Review: $reviewRel (decision: $($review.Decision))"
    exit 0
}

Push-Location $root
try {
    $existing = $null
    try {
        $raw = Invoke-Gh -GhArgs @('pr', 'view', '--json', 'url,number,state,headRefName')
        $existing = (ConvertFrom-GhJson $raw) | Select-Object -First 1
        if ($existing.headRefName -ne $branch) {
            $existing = $null
        }
    }
    catch {
        $existing = $null
    }

    if ($null -eq $existing) {
        Write-Host "Pushing $branch to origin (task/* only; never main)."
        & git push -u origin HEAD
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed with exit $LASTEXITCODE"
        }

        $title = $taskId
        $body = @"
## TASK
``$taskRel``

## Report
``$reportRel``

## Review
``$reviewRel`` (decision: approve)

Do not merge automatically. Only Human merges ``main``.
GitHub Actions must not write ``.agent/state.json``.
Live protocol overlay: gitignored ``.agent/runtime.json``.
"@
        Invoke-Gh -GhArgs @('pr', 'create', '--base', 'main', '--head', $branch, '--title', $title, '--body', $body) | Out-Host
        $raw = Invoke-Gh -GhArgs @('pr', 'view', '--json', 'url,number,state,headRefOid')
        $existing = (ConvertFrom-GhJson $raw) | Select-Object -First 1
    }
    else {
        Write-Host "Reusing existing PR $($existing.url)"
        $raw = Invoke-Gh -GhArgs @('pr', 'view', '--json', 'url,number,state,headRefOid')
        $existing = (ConvertFrom-GhJson $raw) | Select-Object -First 1
    }
}
finally {
    Pop-Location
}

if ($ciRequired) {
    $protocolStatus = 'ci_running'
    $protocolCi = 'running'
}
else {
    $protocolStatus = 'awaiting_merge'
    $protocolCi = 'n/a'
}

$runtime = New-RuntimeObject `
    -TaskId $taskId `
    -PrUrl $existing.url `
    -PrNumber ([int]$existing.number) `
    -HeadSha $existing.headRefOid `
    -CiGate 'pending' `
    -ProtocolStatus $protocolStatus `
    -ProtocolCiStatus $protocolCi `
    -CiRequired $ciRequired `
    -Merged ($existing.state -eq 'MERGED') `
    -Source 'github-pr'

Assert-AwaitingMergeLegal -ProtocolStatus $runtime.protocol_status -CiGate $runtime.ci_gate -CiRequired $ciRequired -ProtocolCiStatus $runtime.protocol_ci_status

$path = Write-RuntimeObject -Runtime $runtime -RepoRoot $root
Write-Host "Wrote live overlay $path"
Write-Host "PR $($runtime.pr_url)"
Write-Host "protocol_status=$($runtime.protocol_status) protocol_ci_status=$($runtime.protocol_ci_status) ci_gate=$($runtime.ci_gate)"
Write-Host 'Next: pwsh -File scripts/workflow/observe-ci.ps1'
Write-Host 'Human merge remains required. Do not gh pr merge.'

# Prepare TASK archive on main after Human merge. Does not push. Does not merge.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden -CommandParts $args

$root = Get-RepoRoot
$branch = Get-CurrentBranch -RepoRoot $root
Assert-OnMain -Branch $branch

Push-Location $root
try {
    $dirty = (& git status --porcelain)
    if ($dirty) {
        throw 'Refused: working tree is not clean. finalize-prep will not mix archive with other edits.'
    }
    & git fetch origin
    $head = (& git rev-parse HEAD).Trim()
    $originMain = (& git rev-parse origin/main).Trim()
    if ($head -ne $originMain) {
        throw "Refused: local main ($head) is not synced with origin/main ($originMain). Human push/pull first."
    }
}
finally {
    Pop-Location
}

$state = Get-StateObject -RepoRoot $root
$runtime = Read-RuntimeObject -RepoRoot $root
$taskId = [string]$state.active_task
if (-not $taskId) {
    throw 'Refused: active_task is null; nothing to archive.'
}

$prNumber = 0
if ($runtime -and $runtime.pr_number) { $prNumber = [int]$runtime.pr_number }
if ($prNumber -le 0) {
    throw 'Refused: runtime.json has no pr_number. Cannot confirm Human merge.'
}

$view = (Invoke-Gh -GhArgs @('pr', 'view', "$prNumber", '--json', 'number,url,state,mergedAt,headRefOid')) | ConvertFrom-Json
if ($view.state -ne 'MERGED' -or -not $view.mergedAt) {
    throw "Refused: PR #$prNumber state=$($view.state) mergedAt=$($view.mergedAt). finalize-prep runs only after Human merge. This script does not merge and does not push."
}

$ciRequired = [bool]$state.ci_required
$durableCi = 'n/a'
if ($ciRequired) {
    if (-not $runtime -or $runtime.ci_gate -ne 'success' -or $runtime.protocol_ci_status -ne 'passed') {
        throw 'Refused: ci_required TASK archive requires observed ci-gate success (runtime overlay). Re-run observe-ci.ps1.'
    }
    $durableCi = 'passed'
}

$taskFile = Find-TaskFile -TaskId $taskId -RepoRoot $root
$destDir = Join-Path $root '.agent\tasks\completed'
$dest = Join-Path $destDir (Split-Path $taskFile -Leaf)

if ($DryRun) {
    Write-Host "DRY RUN: would move $taskFile -> $dest"
    Write-Host "Would set status=completed last_completed_task=$taskId pr_url=$($view.url) ci_status=$durableCi"
    Write-Host 'Would not push.'
    exit 0
}

if (-not (Test-Path -LiteralPath $destDir)) {
    throw "Missing $destDir"
}
Move-Item -LiteralPath $taskFile -Destination $dest

$state.status = 'completed'
$state.last_completed_task = $taskId
$state.active_task = $null
$state.pr_url = $view.url
$state.ci_status = $durableCi
$state.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
$state.agents.cursor.status = 'idle'
$state.agents.review.status = 'idle'

$statePath = Join-Path $root '.agent\state.json'
($state | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $statePath -Encoding UTF8

Write-Host "Archived $taskId -> $dest"
Write-Host "Durable state: status=completed pr_url=$($view.url) ci_status=$durableCi"
Write-Host 'STOP: Human must commit (if this session is not allowed to commit main) and push main. This script does not push.'

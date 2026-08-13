# Read-only view of GitHub Checks + runtime overlay + state.json.
# No writes. No merge. No push.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden -CommandParts $args

$root = Get-RepoRoot
$branch = Get-CurrentBranch -RepoRoot $root
$state = Get-StateObject -RepoRoot $root
$runtime = Read-RuntimeObject -RepoRoot $root

Write-Host '=== git ==='
Write-Host "branch=$branch"
Write-Host "root=$root"

Write-Host '=== .agent/state.json (intent / durable) ==='
Write-Host ($state | ConvertTo-Json -Depth 8)

Write-Host '=== .agent/runtime.json (live overlay; gitignored) ==='
if ($runtime) {
    Write-Host ($runtime | ConvertTo-Json -Depth 8)
}
else {
    Write-Host '(missing)'
}

Write-Host '=== GitHub (read-only) ==='
Push-Location $root
try {
    $prArg = @('pr', 'view', '--json', 'number,url,state,headRefOid,headRefName,mergedAt')
    if ($runtime -and $runtime.pr_number) {
        $prArg = @('pr', 'view', "$($runtime.pr_number)", '--json', 'number,url,state,headRefOid,headRefName,mergedAt')
    }
    try {
        $viewRaw = Invoke-Gh -GhArgs $prArg
        Write-Host $viewRaw
        $view = $viewRaw | ConvertFrom-Json
        $checksRaw = Invoke-Gh -GhArgs @('pr', 'checks', "$($view.number)", '--json', 'name,state,bucket')
        Write-Host $checksRaw
        $checks = @($checksRaw | ConvertFrom-Json)
        $ciGate = Get-CiGateFact -Checks $checks
        Write-Host "observed ci-gate fact=$ciGate"
    }
    catch {
        Write-Host "No PR visible for this branch/runtime: $($_.Exception.Message)"
    }
}
finally {
    Pop-Location
}

Write-Host 'status.ps1 is read-only. Human merges main. Agents must not gh pr merge.'

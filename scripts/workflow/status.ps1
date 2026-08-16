# Read-only view of GitHub Checks + runtime overlay + state.json.
# No writes. No merge. No push.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

$root = Get-RepoRoot
$branch = Get-CurrentBranch -RepoRoot $root
$state = Get-StateObject -RepoRoot $root
$runtime = Read-RuntimeObject -RepoRoot $root

Write-Host '=== git ==='
Write-Host "branch=$branch"
Write-Host "root=$root"

Write-Host '=== .agent/state.json (intent / durable) ==='
Write-Host ($state | ConvertTo-Json -Depth 8)
Write-Host "plan_approved=$($state.plan_approved) (Gate 1; PRIMARY enforcement is start-coding.ps1)"

Write-Host '=== .agent/handoff.md (live session bridge; gitignored) ==='
$handoffPath = Get-HandoffPath -RepoRoot $root
if (Test-Path -LiteralPath $handoffPath) {
    Write-Host (Get-Content -LiteralPath $handoffPath -Raw -Encoding UTF8)
}
else {
    Write-Host '(missing)'
}

Write-Host '=== .agent/runtime.json (live overlay; gitignored) ==='
if ($runtime) {
    Write-Host ($runtime | ConvertTo-Json -Depth 8)
}
else {
    Write-Host '(missing)'
}

Write-Host '=== bootstrap derived (C-001) ==='
try {
    $facts = Get-DerivedHandoffFacts -State $state -RepoRoot $root
    Write-Host "derived next_actor=$($facts.NextActor) next_action=$($facts.NextAction) review_round=$($facts.ReviewRound) decision=$($facts.Decision)"
    Write-Host "required_fixes_file=$($facts.RequiredFixesFile)"
    Write-Host "human_instruction=$($facts.HumanInstruction)"
    try {
        Assert-HandoffMatchesDerived -State $state -RepoRoot $root | Out-Null
        Write-Host 'handoff matches derived facts'
    }
    catch {
        Write-Host $_.Exception.Message
    }
}
catch {
    Write-Host "bootstrap derive failed: $($_.Exception.Message)"
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
        $view = ConvertFrom-GhJson $viewRaw | Select-Object -First 1
        $checksRaw = Invoke-Gh -GhArgs @('pr', 'checks', "$($view.number)", '--json', 'name,state,bucket')
        Write-Host $checksRaw
        $checks = @(ConvertFrom-GhJson $checksRaw)
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

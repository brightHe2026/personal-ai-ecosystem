# D-001 post-merge archive: commit + push main ONLY after independent precondition checks.
# AGENT_D001_ARCHIVE=1 is an internal capability marker, NOT authorization.
# This script never calls gh pr merge and never force-pushes.
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')
Assert-MergeForbidden

function Invoke-D001CapabilityPush {
    param([string]$RepoRoot)
    # Capability marker only — set AFTER independent checks passed. Not authorization.
    # Caller must already have authorized a fresh archive commit or the exact unpushed retry commit.
    $previousMarker = $env:AGENT_D001_ARCHIVE
    $env:AGENT_D001_ARCHIVE = '1'
    try {
        Push-Location $RepoRoot
        try {
            & git push origin main
            if ($LASTEXITCODE -ne 0) {
                throw "git push origin main failed with exit $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        if ($null -eq $previousMarker) {
            Remove-Item Env:AGENT_D001_ARCHIVE -ErrorAction SilentlyContinue
        }
        else {
            $env:AGENT_D001_ARCHIVE = $previousMarker
        }
    }
}

$root = Get-RepoRoot

# Independent authorization. Does not read AGENT_D001_ARCHIVE.
$facts = Assert-D001ArchivePreconditions -RepoRoot $root

if ($facts.Mode -eq 'retry') {
    if ($DryRun) {
        Write-Host "DRY RUN: would retry push of authorized unpushed archive $($facts.RetrySha) for $($facts.TaskId) PR #$($facts.PrNumber) headRefName=$($facts.ExpectedBranch)"
        Write-Host 'Would not treat AGENT_D001_ARCHIVE as authorization. Would not gh pr merge. Would not force push. Would not allow a generic clean-tree push-main.'
        exit 0
    }
    Invoke-D001CapabilityPush -RepoRoot $root
}
else {
    $taskFileActive = $null
    try {
        $taskFileActive = Find-TaskFile -TaskId $facts.TaskId -RepoRoot $root
    }
    catch {
        $taskFileActive = $null
    }

    if ($DryRun) {
        Write-Host "DRY RUN: would apply finalize-prep if needed then D-001 exact-path commit/push for $($facts.TaskId) PR #$($facts.PrNumber) headRefName=$($facts.ExpectedBranch)"
        Write-Host "MERGED=$($facts.View.state) ci_gate=$($facts.CiGate) durable=$($facts.DurableCi)"
        Write-Host 'Would not treat AGENT_D001_ARCHIVE as authorization. Would not gh pr merge. Would not force push. Would not git add entire task directories.'
        exit 0
    }

    if ($taskFileActive) {
        Invoke-FinalizePrepApply -Facts $facts -RepoRoot $root | Out-Null
        $facts = Assert-D001ArchivePreconditions -RepoRoot $root
        if ($facts.Mode -eq 'retry') {
            throw 'Refused: unexpected retry mode after finalize-prep apply (working tree should still be uncommitted).'
        }
    }

    Push-Location $root
    try {
        $nameOnly = @(& git diff --name-only)
        $nameOnly += @(& git diff --name-only --cached)
        $untracked = @(& git ls-files --others --exclude-standard)
        $paths = @($nameOnly + $untracked | Where-Object { $_ } | ForEach-Object { ($_ -replace '\\', '/') } | Select-Object -Unique)
        if ($paths.Count -eq 0) {
            throw 'Refused: no archive diff to commit. Did finalize-prep run?'
        }
        Assert-D001DiffAllowlisted -Paths $paths -TaskId $facts.TaskId

        $exact = @(Get-D001ExactArchivePaths -TaskId $facts.TaskId -RepoRoot $root)
        foreach ($p in $exact) {
            $full = Join-Path $root ($p -replace '/', [IO.Path]::DirectorySeparatorChar)
            $tracked = @(& git ls-files -- $p)
            if ((Test-Path -LiteralPath $full) -or ($tracked.Count -gt 0)) {
                & git add -- $p
                if ($LASTEXITCODE -ne 0) {
                    throw "git add of exact D-001 path failed: $p (exit $LASTEXITCODE)"
                }
            }
        }

        $cached = @(& git diff --cached --name-only | ForEach-Object { ($_ -replace '\\', '/') })
        if ($cached.Count -eq 0) {
            throw 'Refused: no exact D-001 paths staged. Refusing directory-wide add.'
        }
        Assert-D001DiffAllowlisted -Paths $cached -TaskId $facts.TaskId
        foreach ($c in $cached) {
            if ($exact -notcontains $c) {
                throw "Refused: staged path $c is not an exact D-001 path for $($facts.TaskId)."
            }
        }

        $msg = Get-D001ArchiveCommitSubject -TaskId $facts.TaskId
        & git commit -m $msg
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed with exit $LASTEXITCODE"
        }

        $cachedAfter = @(& git diff --cached --name-only)
        if ($cachedAfter) {
            throw 'Refused: unexpected staged files after commit.'
        }
    }
    finally {
        Pop-Location
    }

    Invoke-D001CapabilityPush -RepoRoot $root
}

Write-Handoff `
    -TaskId $facts.TaskId `
    -Status 'completed' `
    -PlanApproved $false `
    -NextActor 'planner' `
    -NextAction 'next-task-or-stop' `
    -Reads @('.agent/tasks/completed/', '.agent/state.json') `
    -Notes 'D-001 archive pushed after independent MERGED+task-bound PR + exact allowlist + live Checks verification. AGENT_D001_ARCHIVE did not authorize the push.' `
    -RepoRoot $root | Out-Null

Write-Host "D-001 archive pushed for $($facts.TaskId) mode=$($facts.Mode)"
Write-Host "durable ci_status=$($facts.DurableCi) pr=$($facts.View.url) headRefName=$($facts.ExpectedBranch)"
Write-Host 'AGENT_D001_ARCHIVE is not authorization. Human merge already happened. Do not gh pr merge.'

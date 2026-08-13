# Local guardrail tests for TASK-005C-C workflow scripts.
# Does not open a PR, merge, or push.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib.ps1')

$failed = 0
$passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        Write-Host "PASS $Name"
        $script:passed++
    }
    else {
        Write-Host "FAIL $Name"
        $script:failed++
    }
}

function Assert-Throws {
    param([scriptblock]$Block, [string]$Name, [string]$Match = '')
    try {
        & $Block | Out-Null
        Write-Host "FAIL $Name (no throw)"
        $script:failed++
    }
    catch {
        $msg = [string]$_.Exception.Message
        if ($Match -and ($msg -notmatch $Match)) {
            Write-Host "FAIL $Name (message='$msg' expected match '$Match')"
            $script:failed++
        }
        else {
            Write-Host "PASS $Name"
            $script:passed++
        }
    }
}

Write-Host '=== mapping / ci-gate fact ==='

Assert-True (Test-IsCiGateName 'ci-gate') 'name ci-gate'
Assert-True (Test-IsCiGateName 'CI / ci-gate') 'name CI / ci-gate'
Assert-True (-not (Test-IsCiGateName 'sales-agent-backend')) 'ignore app job name'
Assert-True (-not (Test-IsCiGateName 'not-ci-gate-extra')) 'do not over-match'

$passGate = [pscustomobject]@{ name = 'ci-gate'; state = 'SUCCESS'; bucket = 'pass' }
$failGate = [pscustomobject]@{ name = 'ci-gate'; state = 'FAILURE'; bucket = 'fail' }
$pendingGate = [pscustomobject]@{ name = 'ci-gate'; state = 'IN_PROGRESS'; bucket = 'pending' }
$skipApp = [pscustomobject]@{ name = 'sales-agent-backend'; state = 'SKIPPED'; bucket = 'skipping' }
$passApp = [pscustomobject]@{ name = 'knowledge-agent-backend'; state = 'SUCCESS'; bucket = 'pass' }

Assert-True ((Get-CiGateFact -Checks @($skipApp, $passGate)) -eq 'success') 'skipped app jobs ignored; ci-gate pass'
Assert-True ((Get-CiGateFact -Checks @($failGate, $passApp)) -eq 'failure') 'ci-gate fail wins'
Assert-True ((Get-CiGateFact -Checks @($pendingGate, $passApp)) -eq 'pending') 'ci-gate pending'
Assert-True ((Get-CiGateFact -Checks @($skipApp, $passApp)) -eq 'failure') 'missing ci-gate after completed jobs is fail-closed'
Assert-True ((Get-CiGateFact -Checks @()) -eq 'pending') 'no checks yet is pending'

Write-Host '=== protocol mapping ==='

$reqPass = Resolve-ProtocolFromCiGate -CiGate 'success' -CiRequired $true
Assert-True ($reqPass.protocol_status -eq 'awaiting_merge' -and $reqPass.protocol_ci_status -eq 'passed') 'required + green -> awaiting_merge/passed'

$reqFail = Resolve-ProtocolFromCiGate -CiGate 'failure' -CiRequired $true
Assert-True ($reqFail.protocol_status -eq 'ci_running' -and $reqFail.protocol_ci_status -eq 'failed') 'required + red stays ci_running/failed'

$reqPend = Resolve-ProtocolFromCiGate -CiGate 'pending' -CiRequired $true
Assert-True ($reqPend.protocol_status -eq 'ci_running' -and $reqPend.protocol_ci_status -eq 'running') 'required + pending stays ci_running'

$noPass = Resolve-ProtocolFromCiGate -CiGate 'success' -CiRequired $false
Assert-True ($noPass.protocol_status -eq 'awaiting_merge' -and $noPass.protocol_ci_status -eq 'n/a') 'not-required keeps n/a even when ci-gate green'

$noFail = Resolve-ProtocolFromCiGate -CiGate 'failure' -CiRequired $false
Assert-True ($noFail.protocol_ci_status -eq 'n/a' -and $noFail.protocol_status -eq 'awaiting_merge') 'not-required does not impersonate passed on red'

Assert-Throws { Resolve-ProtocolFromCiGate -CiGate 'n/a' -CiRequired $true } 'required + n/a throws (retired §2.3)' 'n/a is invalid'

Assert-Throws {
    Assert-AwaitingMergeLegal -ProtocolStatus 'awaiting_merge' -CiGate 'failure' -CiRequired $true -ProtocolCiStatus 'passed'
} 'cannot forge awaiting_merge on red ci-gate' 'cannot enter awaiting_merge'

Assert-Throws {
    Assert-AwaitingMergeLegal -ProtocolStatus 'awaiting_merge' -CiGate 'pending' -CiRequired $true -ProtocolCiStatus 'running'
} 'cannot awaiting_merge while ci-gate pending' 'cannot enter awaiting_merge'

Assert-Throws {
    Assert-AwaitingMergeLegal -ProtocolStatus 'awaiting_merge' -CiGate 'success' -CiRequired $false -ProtocolCiStatus 'passed'
} 'cannot label not-required as passed' 'n/a'

try {
    Assert-AwaitingMergeLegal -ProtocolStatus 'awaiting_merge' -CiGate 'success' -CiRequired $true -ProtocolCiStatus 'passed'
    Assert-True $true 'legal awaiting_merge on real pass'
}
catch {
    Write-Host "FAIL legal awaiting_merge on real pass ($($_.Exception.Message))"
    $failed++
}

Write-Host '=== branch / merge / approve guards ==='

Assert-Throws { Assert-NotMain -Branch 'main' } 'refuse main' 'main'
Assert-Throws { Assert-TaskBranch -Branch 'main' } 'task branch refuse main' 'main'
Assert-Throws { Assert-TaskBranch -Branch 'feature/foo' } 'refuse non-task branch' 'task/'
Assert-Throws { Assert-OnMain -Branch 'task/TASK-005C-C-ci-state-integration' } 'finalize refuses task branch' 'only on main'
Assert-Throws { Assert-MergeForbidden -CommandParts @('pr', 'merge', '2') } 'forbid pr merge args' 'must not merge'

Assert-Throws { Assert-ReviewApproved -TaskId 'TASK-NO-SUCH-REVIEW' } 'open-pr without approve' 'no Independent Review'

$bReview = Get-LatestReview -TaskId 'TASK-005C-B'
Assert-True ($null -ne $bReview -and $bReview.Decision -eq 'approve') 'can read historical approve review'

$cReview = Get-LatestReview -TaskId 'TASK-005C-C'
Assert-True ($null -ne $cReview -and $cReview.Decision -eq 'approve') 'TASK-005C-C review is approve'

Write-Host '=== script surface ==='

$scriptDir = $PSScriptRoot
$scriptFiles = Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' | Where-Object { $_.Name -ne 'test-guardrails.ps1' }
$mergeHits = @()
$pushMainHits = @()
foreach ($f in $scriptFiles) {
    $lines = Get-Content -LiteralPath $f.FullName
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim.StartsWith('#')) { continue }
        if ($trim -match "Invoke-Gh[^\n]*'merge'" -or $trim -match "GhArgs\s*=\s*@\('pr',\s*'merge'" -or $trim -match '& \$gh\s+pr\s+merge') {
            $mergeHits += "$($f.Name): $trim"
        }
        if ($trim -match 'push\s+(-u\s+)?origin\s+main(\s|$)' -or $trim -match 'git\s+push\s+[^\n]*\sorigin\s+main(\s|$)') {
            $pushMainHits += "$($f.Name): $trim"
        }
    }
}
Assert-True ($mergeHits.Count -eq 0) 'no gh pr merge in scripts'
Assert-True ($pushMainHits.Count -eq 0) "no git push main in scripts ($($pushMainHits -join '; '))"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $scriptDir 'merge.ps1'))) 'no merge.ps1'

$finalizeSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'finalize-prep.ps1') -Raw
Assert-True ($finalizeSrc -match 'state -ne ''MERGED''' -or $finalizeSrc -match 'state -ne "MERGED"') 'finalize-prep requires GitHub MERGED'
Assert-True ($finalizeSrc -match 'mergedAt') 'finalize-prep requires mergedAt'
Assert-True ($finalizeSrc -notmatch '(?m)^[^#\n]*\bgit\s+push\b') 'finalize-prep has no git push'
Assert-True ($finalizeSrc -notmatch "GhArgs @\('pr',\s*'merge'") 'finalize-prep has no pr merge'

$openSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'open-pr.ps1') -Raw
Assert-True ($openSrc -notmatch 'CI Gate / Workflow State Integration') 'open-pr title is not this-TASK-specific'

Write-Host '=== open-pr dry-run (isolated process; must not kill harness) ==='
$openPrFile = Join-Path $scriptDir 'open-pr.ps1'
$openOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $openPrFile -DryRun 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    Assert-True $true 'open-pr dry-run succeeds at git_ready + approve'
}
else {
    Write-Host "FAIL open-pr dry-run at git_ready (exit=$LASTEXITCODE) $openOut"
    $failed++
}

Write-Host '=== observe-ci without PR ==='
$observeFile = Join-Path $scriptDir 'observe-ci.ps1'
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$obsOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $observeFile -DryRun 2>&1 | Out-String
$obsCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($obsCode -ne 0 -and $obsOut -match 'no PR') {
    Assert-True $true 'observe-ci without PR is a clear error'
}
else {
    Write-Host "FAIL observe-ci without PR (exit=$obsCode) $obsOut"
    $failed++
}

Write-Host '=== finalize-prep dry-run refuses task branch ==='
Assert-Throws {
    & (Join-Path $scriptDir 'finalize-prep.ps1') -DryRun
} 'finalize-prep refuses task/*' 'only on main'

Write-Host '=== gitignore overlay ==='
$root = Get-RepoRoot
Assert-True (Test-GitignoreRuntime -RepoRoot $root) '.agent/runtime.json is gitignored'

Write-Host '=== ci.yml untouched contract ==='
$ci = Get-Content -LiteralPath (Join-Path $root '.github\workflows\ci.yml') -Raw
Assert-True ($ci -match 'permissions:\s+contents:\s+read') 'ci.yml still contents:read'
Assert-True ($ci -notmatch 'contents:\s+write') 'ci.yml has no contents:write'
Assert-True ($ci -notmatch 'git commit' -and $ci -notmatch 'git push') 'ci.yml does not write git'

Write-Host ''
Write-Host "Passed=$passed Failed=$failed"
if ($failed -gt 0) {
    exit 1
}
exit 0

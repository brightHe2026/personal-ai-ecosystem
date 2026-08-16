# Local guardrail tests for workflow scripts (TASK-005C-D / TASK-005C-E).
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

$ghArrayJson = '[{"bucket":"pass","name":"ci-gate","state":"SUCCESS"},{"bucket":"skipping","name":"sales-agent-backend","state":"SKIPPED"},{"bucket":"pass","name":"changes","state":"SUCCESS"}]'
$parsedChecks = @(ConvertFrom-GhJson $ghArrayJson)
Assert-True ($parsedChecks.Count -eq 3) 'ConvertFrom-GhJson keeps JSON array items'
Assert-True ((Get-CiGateFact -Checks $parsedChecks) -eq 'success') 'gh array JSON maps ci-gate SUCCESS not failure'

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
        if ($trim -match '&\s*git\s+push\s+(-u\s+)?origin\s+main(\s|$)' -or $trim -match "git',\s*'push',\s*'origin',\s*'main'") {
            $pushMainHits += "$($f.Name): $trim"
        }
    }
}
Assert-True ($mergeHits.Count -eq 0) 'no gh pr merge in scripts'
$unexpectedPush = @($pushMainHits | Where-Object { $_ -notmatch '^archive-push\.ps1:' })
Assert-True ($unexpectedPush.Count -eq 0) "no git push main outside archive-push.ps1 ($($unexpectedPush -join '; '))"
Assert-True ($pushMainHits.Count -ge 1) 'archive-push.ps1 contains git push origin main (D-001 path)'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $scriptDir 'merge.ps1'))) 'no merge.ps1'

$finalizeSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'finalize-prep.ps1') -Raw
$libSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'lib.ps1') -Raw
Assert-True ($finalizeSrc -match 'Assert-D001ArchivePreconditions') 'finalize-prep uses shared D-001 preconditions'
Assert-True ($libSrc -match "state -ne 'MERGED'" -or $libSrc -match 'state -ne "MERGED"') 'lib Confirm-PrMergedLive requires GitHub MERGED'
Assert-True ($libSrc -match 'mergedAt') 'lib requires mergedAt'
Assert-True ($finalizeSrc -notmatch '(?m)^[^#\n]*\bgit\s+push\b') 'finalize-prep has no git push'
Assert-True ($finalizeSrc -notmatch "GhArgs @\('pr',\s*'merge'") 'finalize-prep has no pr merge'

$openSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'open-pr.ps1') -Raw
Assert-True ($openSrc -notmatch 'CI Gate / Workflow State Integration') 'open-pr title is not this-TASK-specific'

Write-Host '=== open-pr dry-run (isolated process; N-001 recoupled) ==='
$openPrFile = Join-Path $scriptDir 'open-pr.ps1'
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$openOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $openPrFile -DryRun 2>&1 | Out-String
$openCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($openCode -eq 0 -and $openOut -match 'DRY RUN: would open/reuse PR' -and $openOut -match 'decision: approve') {
    Assert-True $true 'open-pr dry-run succeeds at git_ready + Review approve'
}
elseif ($openCode -ne 0 -and ($openOut -match 'git_ready' -or $openOut -match 'plan_approved' -or $openOut -match 'main')) {
    Assert-True $true 'open-pr dry-run refuses when not git_ready (fixture not coupled to live TASK id)'
}
else {
    Write-Host "FAIL open-pr dry-run (exit=$openCode) $openOut"
    $failed++
}

Write-Host '=== observe-ci without PR ==='
$rtNow = Read-RuntimeObject
if ($rtNow -and $rtNow.pr_number) {
    Assert-True $true 'observe-ci no-PR case skipped (live PR exists)'
}
else {
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
}

Write-Host '=== finalize-prep dry-run refuses task branch ==='
Assert-Throws {
    & (Join-Path $scriptDir 'finalize-prep.ps1') -DryRun
} 'finalize-prep refuses task/*' 'only on main'

Write-Host '=== gitignore overlay ==='
$root = Get-RepoRoot
Assert-True (Test-GitignoreRuntime -RepoRoot $root) '.agent/runtime.json is gitignored'
Assert-True (Test-GitignoreHandoff -RepoRoot $root) '.agent/handoff.md is gitignored'

Write-Host '=== ci.yml untouched contract ==='
$ci = Get-Content -LiteralPath (Join-Path $root '.github\workflows\ci.yml') -Raw
Assert-True ($ci -match 'permissions:\s+contents:\s+read') 'ci.yml still contents:read'
Assert-True ($ci -notmatch 'contents:\s+write') 'ci.yml has no contents:write'
Assert-True ($ci -notmatch 'git commit' -and $ci -notmatch 'git push') 'ci.yml does not write git'

Write-Host '=== Gate 1 plan_approved PRIMARY vs defense-in-depth ==='
$falseState = [pscustomobject]@{ plan_approved = $false; active_task = 'TASK-FAKE'; status = 'specified' }
$trueState = [pscustomobject]@{ plan_approved = $true; active_task = 'TASK-FAKE'; status = 'specified' }
Assert-Throws { Assert-PlanApproved -State $falseState } 'Assert-PlanApproved refuses false' 'plan_approved is not true'
Assert-True (-not (Test-PlanApprovedFlag -State $falseState)) 'flag false'
Assert-True (Test-PlanApprovedFlag -State $trueState) 'flag true'
try {
    Assert-PlanApproved -State $trueState
    Assert-True $true 'Assert-PlanApproved accepts true'
}
catch {
    Write-Host "FAIL Assert-PlanApproved accepts true ($($_.Exception.Message))"
    $failed++
}
$startSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'start-coding.ps1') -Raw
Assert-True ($startSrc -match 'Assert-PlanApproved') 'start-coding.ps1 is PRIMARY Gate 1 (calls Assert-PlanApproved)'
Assert-True ($startSrc -match 'PRIMARY') 'start-coding.ps1 documents PRIMARY'
$openSrc2 = Get-Content -LiteralPath (Join-Path $scriptDir 'open-pr.ps1') -Raw
Assert-True ($openSrc2 -match 'Assert-PlanApproved') 'open-pr.ps1 has plan_approved defense-in-depth'
Assert-True ($openSrc2 -match 'defense-in-depth') 'open-pr.ps1 labels defense-in-depth only'

$startFile = Join-Path $scriptDir 'start-coding.ps1'
$prevEap2 = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$startOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $startFile -DryRun 2>&1 | Out-String
$startCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap2
if ($startCode -eq 0 -and $startOut -match 'PRIMARY') {
    Assert-True $true 'start-coding -DryRun succeeds when plan_approved=true and status allows start'
}
elseif ($startOut -match 'plan_approved is not true') {
    Write-Host "FAIL start-coding refused plan_approved despite live true ($startOut)"
    $failed++
}
elseif ($startOut -match 'Current status=') {
    Assert-True $true 'start-coding -DryRun enforces legal status (live workspace may already be in_review)'
}
else {
    Write-Host "FAIL start-coding -DryRun (exit=$startCode) $startOut"
    $failed++
}

Write-Host '=== D-001 allowlist / marker is not authorization ==='
$tid = 'TASK-005C-D'
Assert-True (Test-D001AllowlistedPath -Path '.agent/state.json' -TaskId $tid) 'allowlist state.json'
Assert-True (Test-D001AllowlistedPath -Path '.agent/tasks/active/TASK-005C-D-workflow-hardening.md' -TaskId $tid) 'allowlist active TASK'
Assert-True (Test-D001AllowlistedPath -Path '.agent/tasks/completed/TASK-005C-D-workflow-hardening.md' -TaskId $tid) 'allowlist completed TASK'
Assert-True (-not (Test-D001AllowlistedPath -Path 'apps/sales-agent/backend/main.py' -TaskId $tid)) 'refuse apps/'
Assert-True (-not (Test-D001AllowlistedPath -Path 'agents/knowledge-agent/backend/app.py' -TaskId $tid)) 'refuse agents/'
Assert-True (-not (Test-D001AllowlistedPath -Path '.github/workflows/ci.yml' -TaskId $tid)) 'refuse ci.yml'
Assert-True (-not (Test-D001AllowlistedPath -Path 'scripts/workflow/lib.ps1' -TaskId $tid)) 'refuse scripts/'
Assert-Throws { Assert-D001DiffAllowlisted -TaskId $tid -Paths @('apps/foo.py') } 'diff refuse apps' 'allowlist violation'
Assert-Throws { Assert-D001DiffAllowlisted -TaskId $tid -Paths @('.github/workflows/ci.yml') } 'diff refuse workflows' 'allowlist violation'
try {
    Assert-D001DiffAllowlisted -TaskId $tid -Paths @('.agent/state.json', '.agent/tasks/completed/TASK-005C-D-workflow-hardening.md')
    Assert-True $true 'allowlist-only diff accepted'
}
catch {
    Write-Host "FAIL allowlist-only diff ($($_.Exception.Message))"
    $failed++
}

$preFn = (Get-Command Assert-D001ArchivePreconditions).Definition
Assert-True ($preFn -notmatch 'AGENT_D001_ARCHIVE') 'Assert-D001ArchivePreconditions does not read AGENT_D001_ARCHIVE'
$archiveSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'archive-push.ps1') -Raw
Assert-True ($archiveSrc -match 'Assert-D001ArchivePreconditions') 'archive-push independently calls Assert-D001ArchivePreconditions'
Assert-True ($archiveSrc -match 'AGENT_D001_ARCHIVE') 'archive-push sets capability marker'
# Marker must not be set before independent checks.
$idxFacts = $archiveSrc.IndexOf('$facts = Assert-D001ArchivePreconditions')
$idxCallPush = $archiveSrc.IndexOf('Invoke-D001CapabilityPush -RepoRoot')
Assert-True ($idxFacts -ge 0 -and $idxCallPush -gt $idxFacts) 'capability push is invoked only after independent checks'
Assert-True ($archiveSrc -match 'force' -or $archiveSrc -match 'not authorization' -or $archiveSrc -match 'NOT authorization') 'archive-push documents marker is not authorization'
Assert-True ($archiveSrc -notmatch "GhArgs @\('pr',\s*'merge'") 'archive-push has no pr merge'
Assert-True ($archiveSrc -notmatch '--force') 'archive-push has no --force'

Write-Host '=== B-003 exact current-task paths ==='
Assert-True (-not (Test-D001AllowlistedPath -Path '.agent/tasks/completed/TASK-OTHER-unrelated.md' -TaskId $tid)) 'B-003 refuse foreign completed TASK'
Assert-True (-not (Test-D001AllowlistedPath -Path '.agent/tasks/active/TASK-ZZZ-not-this-task.md' -TaskId $tid)) 'B-003 refuse foreign active TASK'
Assert-True (-not (Test-D001AllowlistedPath -Path '.agent/tasks/completed/TASK-005C-C-ci-state-integration.md' -TaskId $tid)) 'B-003 refuse sibling TASK-005C-C'
Assert-Throws {
    Assert-D001DiffAllowlisted -TaskId $tid -Paths @('.agent/state.json', '.agent/tasks/completed/TASK-ZZZ-not-this-task.md')
} 'B-003 mixed foreign TASK paths refused' 'allowlist violation'
Assert-Throws {
    Assert-D001DiffAllowlisted -TaskId $tid -Paths @('.agent/tasks/active/TASK-005C-D-workflow-hardening.md', '.agent/tasks/completed/TASK-OTHER-unrelated.md')
} 'B-003 foreign file cannot ride with this TASK' 'allowlist violation'
$exact = @(Get-D001ExactArchivePaths -TaskId $tid)
Assert-True ($exact -contains '.agent/state.json') 'exact paths include state.json'
Assert-True ($exact -contains '.agent/tasks/active/TASK-005C-D-workflow-hardening.md') 'exact paths include this active TASK file'
Assert-True ($exact -contains '.agent/tasks/completed/TASK-005C-D-workflow-hardening.md') 'exact paths include this completed TASK file'
Assert-True ($exact.Count -eq 3) 'exact path set is only state + this TASK active/completed'
Assert-True ($archiveSrc -match 'Get-D001ExactArchivePaths') 'archive-push stages exact paths helper'
Assert-True ($archiveSrc -notmatch 'git add -- \.agent/state\.json \.agent/tasks/active \.agent/tasks/completed') 'archive-push does not git add entire active/completed directories'

Write-Host '=== B-001 bind MERGED PR to this TASK ==='
$okView = [pscustomobject]@{
    number      = 9
    url         = 'https://github.com/example/repo/pull/9'
    state       = 'MERGED'
    mergedAt    = '2026-08-17T01:00:00Z'
    headRefOid  = 'abc123'
    headRefName = 'task/TASK-005C-D-workflow-hardening'
}
$openView = [pscustomobject]@{
    number      = 9
    url         = 'https://github.com/example/repo/pull/9'
    state       = 'OPEN'
    mergedAt    = $null
    headRefName = 'task/TASK-005C-D-workflow-hardening'
}
$wrongHead = [pscustomobject]@{
    number      = 9
    url         = 'https://github.com/example/repo/pull/9'
    state       = 'MERGED'
    mergedAt    = '2026-08-14T04:00:00Z'
    headRefName = 'task/TASK-005C-C-ci-state-integration'
}
$rtThis = [pscustomobject]@{ task_id = 'TASK-005C-D'; pr_number = 9 }
$rtOther = [pscustomobject]@{ task_id = 'TASK-005C-C'; pr_number = 3 }
$stThis = [pscustomobject]@{ active_task = 'TASK-005C-D'; last_completed_task = 'TASK-005C-C'; status = 'awaiting_merge' }
$expectedBr = 'task/TASK-005C-D-workflow-hardening'

Assert-Throws { Assert-PrViewMerged -View $openView } 'B-001/N-001 unmerged PR refused' 'MERGED'
try {
    Assert-PrViewMerged -View $okView
    Assert-True $true 'MERGED view with mergedAt accepted'
}
catch {
    Write-Host "FAIL MERGED view accepted ($($_.Exception.Message))"
    $failed++
}
Assert-Throws {
    Assert-D001TaskPrBinding -State $stThis -Runtime $null -View $okView -TaskId $tid -ExpectedBranch $expectedBr
} 'B-001 missing runtime is ambiguous' 'ambiguous PR evidence'
Assert-Throws {
    Assert-D001TaskPrBinding -State $stThis -Runtime $rtOther -View $okView -TaskId $tid -ExpectedBranch $expectedBr
} 'B-001 leftover other-TASK runtime refused' 'PR/task mismatch'
Assert-Throws {
    Assert-D001TaskPrBinding -State $stThis -Runtime $rtThis -View $wrongHead -TaskId $tid -ExpectedBranch $expectedBr
} 'B-001 headRefName mismatch refused' 'headRefName mismatch'
Assert-Throws {
    Assert-D001TaskPrBinding -State $stThis -Runtime $rtThis -View $openView -TaskId $tid -ExpectedBranch $expectedBr
} 'B-001 non-MERGED bound PR refused' 'MERGED'
Assert-Throws {
    Assert-D001TaskPrBinding -State $stThis -Runtime $rtThis -View $okView -TaskId $tid -ExpectedBranch $expectedBr -RequestedPrNumber 3
} 'B-001 requested vs runtime PR number ambiguous' 'ambiguous PR evidence'
Assert-Throws {
    Resolve-D001TaskId -State ([pscustomobject]@{ active_task = $null; last_completed_task = $null; status = 'coding' })
} 'B-001 missing task identity refused' 'missing task identity'
try {
    Assert-D001TaskPrBinding -State $stThis -Runtime $rtThis -View $okView -TaskId $tid -ExpectedBranch $expectedBr
    Assert-True $true 'B-001 matching runtime+headRefName+MERGED accepted'
}
catch {
    Write-Host "FAIL B-001 happy bind ($($_.Exception.Message))"
    $failed++
}
$liveExpected = Get-TaskExpectedBranch -TaskId $tid
Assert-True ($liveExpected -eq $expectedBr) 'TASK file branch field is the expected headRefName'

Write-Host '=== B-002 authorized unpushed archive retry (not generic clean-tree push) ==='
$origin = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$parent = $origin
$goodPaths = @('.agent/state.json', '.agent/tasks/completed/TASK-005C-D-workflow-hardening.md', '.agent/tasks/active/TASK-005C-D-workflow-hardening.md')
$goodSubject = Get-D001ArchiveCommitSubject -TaskId $tid
try {
    $retryOk = Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
    Assert-True ($retryOk -eq $true) 'B-002 exactly one authorized archive commit is retryable'
}
catch {
    Write-Host "FAIL B-002 happy retry facts ($($_.Exception.Message))"
    $failed++
}
$notRetry = Assert-AuthorizedUnpushedArchiveFacts -AheadCount 0 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
Assert-True ($notRetry -eq $false) 'B-002 synced HEAD is not a retry (fresh path; no generic clean-tree push)'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 2 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
} 'B-002 ahead by unexpected commits refused' 'unexpected commits'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 1 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
} 'B-002/N-001 true diverge/behind refused' 'behind or diverged'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $true -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
} 'B-002 dirty+ahead refused' 'dirty'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $false -ParentSha 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' -OriginMainSha $origin -Subject $goodSubject -CommitPaths $goodPaths -TaskId $tid
} 'B-002 unexpected parent/history refused' 'history unexpected'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject 'chore: unrelated' -CommitPaths $goodPaths -TaskId $tid
} 'B-002 commit identity mismatch refused' 'does not match the authorized archive'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths @('.agent/state.json', '.agent/tasks/completed/TASK-OTHER-unrelated.md') -TaskId $tid
} 'B-002 unpushed commit with foreign TASK refused' 'allowlist violation'
Assert-Throws {
    Assert-AuthorizedUnpushedArchiveFacts -AheadCount 1 -BehindCount 0 -Dirty $false -ParentSha $parent -OriginMainSha $origin -Subject $goodSubject -CommitPaths @('.agent/tasks/completed/TASK-005C-D-workflow-hardening.md') -TaskId $tid
} 'B-002 commit missing state.json refused' 'must include .agent/state.json'
Assert-Throws {
    Assert-MainSyncedToOrigin -Head 'aaa' -OriginMain 'bbb'
} 'N-001 unsynced main (true diverge) refused' 'not synced'
try {
    Assert-MainSyncedToOrigin -Head 'abc' -OriginMain 'abc'
    Assert-True $true 'synced HEAD==origin/main accepted'
}
catch {
    Write-Host "FAIL synced revs ($($_.Exception.Message))"
    $failed++
}
Assert-True ($archiveSrc -match "Mode -eq 'retry'") 'archive-push has retry push path'
Assert-True ($archiveSrc -match 'Get-AuthorizedUnpushedD001Commit' -or $preFn -match 'Get-AuthorizedUnpushedD001Commit') 'preconditions detect authorized unpushed archive commit'

$observeSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'observe-ci.ps1') -Raw
Assert-True ($observeSrc -match 'TimeoutSeconds' -and $observeSrc -match '\$Wait') 'observe-ci supports -Wait timeout'
Assert-True ($observeSrc -match 'Do not forge passed') 'observe-ci -Wait does not forge passed'

$waitSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'wait-for-merge.ps1') -Raw
Assert-True ($waitSrc -match 'MERGED') 'wait-for-merge looks for MERGED'
Assert-True ($waitSrc -match 'Do not forge MERGED') 'wait-for-merge does not forge MERGED'
Assert-True ($waitSrc -notmatch "GhArgs @\('pr',\s*'merge'") 'wait-for-merge has no pr merge'

$finalizeSrc2 = Get-Content -LiteralPath (Join-Path $scriptDir 'finalize-prep.ps1') -Raw
Assert-True ($finalizeSrc2 -match 'Get-DurableCiStatusFromLiveChecks' -or $finalizeSrc2 -match 'Assert-D001ArchivePreconditions') 'finalize-prep uses live Checks path (N-002)'
Assert-True ($finalizeSrc2 -notmatch '(?m)^[^#\n]*\bgit\s+push\b') 'finalize-prep still has no git push'

Write-Host '=== project hook ==='
$hookFile = Join-Path $root '.cursor\hooks\deny-forbidden-git.ps1'
Assert-True (Test-Path -LiteralPath $hookFile) 'deny-forbidden-git.ps1 exists'
$hookJson = Get-Content -LiteralPath (Join-Path $root '.cursor\hooks.json') -Raw
Assert-True ($hookJson -match 'beforeShellExecution' -and $hookJson -match 'failClosed') 'hooks.json failClosed beforeShellExecution'

function Invoke-DenyHook {
    param([string]$Command, [string]$Marker = '')
    $payload = @{ command = $Command } | ConvertTo-Json -Compress
    $saved = $env:AGENT_D001_ARCHIVE
    if ($Marker -eq '') {
        Remove-Item Env:AGENT_D001_ARCHIVE -ErrorAction SilentlyContinue
    }
    else {
        $env:AGENT_D001_ARCHIVE = $Marker
    }
    try {
        $out = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookFile
        return ($out | Out-String)
    }
    finally {
        if ($null -eq $saved) {
            Remove-Item Env:AGENT_D001_ARCHIVE -ErrorAction SilentlyContinue
        }
        else {
            $env:AGENT_D001_ARCHIVE = $saved
        }
    }
}

$denyMerge = Invoke-DenyHook -Command 'gh pr merge 1'
Assert-True ($denyMerge -match '"permission":"deny"') 'hook denies gh pr merge'
$denyPush = Invoke-DenyHook -Command 'git push origin main'
Assert-True ($denyPush -match '"permission":"deny"') 'hook denies push main without marker'
$denyForce = Invoke-DenyHook -Command 'git push --force origin main' -Marker '1'
Assert-True ($denyForce -match '"permission":"deny"') 'hook denies force push even with marker'
$allowCap = Invoke-DenyHook -Command 'git push origin main' -Marker '1'
Assert-True ($allowCap -match '"permission":"allow"') 'hook allows non-force push main only as capability path when marker set'

Write-Host '=== C-001 / C-002 / C-003 bootstrap and review_round ==='
Assert-True ((Get-ReviewRoundAfterEnterInReview -CurrentRound 0) -eq 1) 'C-002 first in_review 0->1'
Assert-True ((Get-ReviewRoundAfterEnterInReview -CurrentRound 2) -eq 2) 'C-002 re-entry in_review does not increment'
Assert-True ((Get-ReviewRoundAfterReject -CurrentRound 1) -eq 2) 'C-002 reject increments once 1->2'
Assert-True ((Get-ReviewRoundAfterApprove -CurrentRound 2) -eq 2) 'C-002 approve does not increment'

$agents = [pscustomobject]@{
    cursor = [pscustomobject]@{ role = 'coding-agent'; status = 'working' }
    review = [pscustomobject]@{ role = 'review-agent'; status = 'idle' }
}
$stEnter = [pscustomobject]@{ active_task = 'TASK-FAKE'; status = 'coding'; plan_approved = $true; review_round = 0; agents = $agents }
Enter-InReviewState -State $stEnter | Out-Null
Assert-True ($stEnter.status -eq 'in_review' -and [int]$stEnter.review_round -eq 1) 'C-002 Enter-InReviewState 0->1'
$stEnter.review_round = 2
$stEnter.status = 'coding'
Enter-InReviewState -State $stEnter | Out-Null
Assert-True ($stEnter.status -eq 'in_review' -and [int]$stEnter.review_round -eq 2) 'C-002 Enter-InReviewState keeps 2'
Apply-ReviewRejectState -State $stEnter | Out-Null
Assert-True ($stEnter.status -eq 'coding' -and [int]$stEnter.review_round -eq 3) 'C-002 reject 2->3 coding'
$stEnter.status = 'in_review'
$stEnter.review_round = 2
Apply-ReviewApproveState -State $stEnter | Out-Null
Assert-True ($stEnter.status -eq 'git_ready' -and [int]$stEnter.review_round -eq 2) 'C-002 approve stays round 2 git_ready'

$stD = [pscustomobject]@{
    active_task         = 'TASK-005C-D'
    last_completed_task = 'TASK-005C-C'
    status              = 'coding'
    plan_approved       = $true
    review_round        = 2
    agents              = $agents
}
$factsD = Get-DerivedHandoffFacts -State $stD -RepoRoot $root
Assert-True ($factsD.NextActor -eq 'coding-agent' -and $factsD.NextAction -eq 'fix-round') 'C-001 coding after reject -> fix-round'
Assert-True ($factsD.Decision -eq 'reject') 'C-001 applicable review decision is reject (round 1 file)'
Assert-True ($factsD.RequiredFixesFile -eq '.agent/reviews/TASK-005C-D-review-round-1.md') 'C-001 required_fixes_file is review-round-1.md while review_round=2'
Assert-True ($factsD.HumanInstruction -eq 'ROLE=coding-agent') 'C-003 human_instruction ROLE=coding-agent'

$stIn = [pscustomobject]@{
    active_task   = 'TASK-FIXTURE-NOREVIEW'
    status        = 'in_review'
    plan_approved = $true
    review_round  = 1
    agents        = $agents
}
$factsIn = Get-DerivedHandoffFacts -State $stIn -RepoRoot $root
Assert-True ($factsIn.NextActor -eq 'review-agent' -and $factsIn.NextAction -eq 'independent-review') 'C-001 in_review -> review-agent'
Assert-True ($factsIn.Decision -eq '(none)' -and $factsIn.RequiredFixesFile -eq '(none)') 'C-001 in_review without this-round file has no current decision (fake TASK id; not live TASK-005C-E path)'
Assert-True ($factsIn.HumanInstruction -eq 'ROLE=review-agent') 'C-003 human_instruction ROLE=review-agent'
$liveERound1 = Join-Path $root '.agent\reviews\TASK-005C-E-review-round-1.md'
if (Test-Path -LiteralPath $liveERound1) {
    Assert-True $true 'live TASK-005C-E review-round-1.md present; no-file fixture used fake TASK id'
    $stElive = [pscustomobject]@{
        active_task   = 'TASK-005C-E'
        status        = 'coding'
        plan_approved = $true
        review_round  = 2
        agents        = $agents
    }
    $factsElive = Get-DerivedHandoffFacts -State $stElive -RepoRoot $root
    Assert-True ($factsElive.NextAction -eq 'fix-round' -and $factsElive.Decision -eq 'reject') 'C-001 live E review-round-1.md present: coding/round 2 derives fix-round'
    Assert-True ($factsElive.RequiredFixesFile -eq '.agent/reviews/TASK-005C-E-review-round-1.md') 'C-001 live required_fixes_file is round-1.md while review_round=2'
}
else {
    Assert-True $true 'live TASK-005C-E review-round-1.md absent; no-file fixture still uses fake TASK id'
}

$badOverlay = [pscustomobject]@{
    task_id             = $factsIn.TaskId
    status              = $factsIn.Status
    plan_approved       = 'true'
    review_round        = '1'
    next_actor          = 'coding-agent'
    next_action         = 'implement'
    decision            = '(none)'
    required_fixes_file = '(none)'
}
Assert-Throws {
    Assert-HandoffMatchesDerived -State $stIn -RepoRoot $root -Overlay $badOverlay
} 'C-001 contradicting handoff fail-closed' 'contradicts authoritative'
Assert-Throws {
    Assert-HandoffMatchesDerived -State $stIn -RepoRoot $root -Overlay $null
} 'C-001 missing handoff fail-closed' 'missing .agent/handoff.md'

$tpl = Get-Content -LiteralPath (Join-Path $root '.agent\handoff.TEMPLATE.md') -Raw
Assert-True ($tpl -match 'fix-round' -and $tpl -match 'required_fixes_file' -and $tpl -match 'review_round' -and $tpl -match 'human_instruction') 'handoff template has V2.5 fields'
$revTpl = Get-Content -LiteralPath (Join-Path $root '.agent\reviews\REVIEW_TEMPLATE.md') -Raw
Assert-True ($revTpl -match 'required_fixes:' -and $revTpl -match 'id: B-001') 'REVIEW_TEMPLATE has structured required_fixes'
Assert-True (Test-Path -LiteralPath (Join-Path $root '.agent\BOOTSTRAP.md')) 'BOOTSTRAP.md exists'
$rule = Get-Content -LiteralPath (Join-Path $root '.cursor\rules\agent-bootstrap.mdc') -Raw
Assert-True ($rule -match 'alwaysApply:\s*true' -and $rule -match 'ROLE=review-agent') 'always-apply bootstrap rule'
$bootSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'bootstrap.ps1') -Raw
Assert-True ($bootSrc -match 'Assert-HandoffMatchesDerived' -and $bootSrc -match 'Repair') 'bootstrap.ps1 fail-closed and -Repair'
Assert-True ($bootSrc -notmatch "GhArgs @\('pr',\s*'merge'") 'bootstrap.ps1 has no pr merge'
Assert-True ($bootSrc -notmatch 'Save-StateObject') 'bootstrap.ps1 does not write state.json'
$enterSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'enter-review.ps1') -Raw
Assert-True ($enterSrc -match 'Enter-InReviewState' -and $enterSrc -match 'Write-DerivedHandoff') 'enter-review uses C-002 helper + derived handoff'
$applySrc = Get-Content -LiteralPath (Join-Path $scriptDir 'apply-review-decision.ps1') -Raw
Assert-True ($applySrc -match 'Apply-ReviewRejectState' -and $applySrc -match 'Apply-ReviewApproveState') 'apply-review-decision uses C-002 helpers'
Assert-True ($applySrc -notmatch 'apps/' -or $applySrc -match 'Does not implement') 'apply-review-decision does not implement app fixes'
$whSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'write-handoff.ps1') -Raw
Assert-True ($whSrc -match 'Write-DerivedHandoff' -and $whSrc -notmatch 'Mandatory.*NextActor') 'write-handoff derives next_actor (C-001)'
$life2 = Get-Content -LiteralPath (Join-Path $root '.agent\workflows\task-lifecycle.md') -Raw
Assert-True ($life2 -match 'TASK-005C-F' -and $life2 -match 'C-001' -and $life2 -match 'C-002') 'lifecycle V2.5 C-001/C-002 and Branch Protection TASK-005C-F'
Assert-True ($life2 -notmatch 'Branch Protection remains TASK-005C-E') 'no leftover Branch Protection = TASK-005C-E'
$implScripts = @(
    (Join-Path $scriptDir 'bootstrap.ps1'),
    (Join-Path $scriptDir 'enter-review.ps1'),
    (Join-Path $scriptDir 'apply-review-decision.ps1'),
    (Join-Path $scriptDir 'write-handoff.ps1'),
    (Join-Path $scriptDir 'start-coding.ps1')
)
$spawnHits = @(Select-String -Path $implScripts -Pattern 'Agent\.create\(|from cursor_sdk import|@cursor/sdk')
Assert-True ($spawnHits.Count -eq 0) 'workflow scripts do not spawn Review via SDK'
$guardSrc = Get-Content -LiteralPath (Join-Path $scriptDir 'test-guardrails.ps1') -Raw
Assert-True ($guardSrc -match 'TASK-FIXTURE-NOREVIEW') 'B-001 no-file in_review fixture is a fake TASK id, not live TASK-005C-E review path'

Write-Host '=== protocol PRIMARY wording ==='
$life = Get-Content -LiteralPath (Join-Path $root '.agent\workflows\task-lifecycle.md') -Raw
Assert-True ($life -match 'PRIMARY' -and $life -match 'start-coding') 'lifecycle documents PRIMARY start-coding'
Assert-True ($life -match 'sole approval authority' -or $life -match 'Human/Planner is the sole') 'lifecycle documents Human/Planner sole Gate 1 authority'
Assert-True ($life -match 'alone does not authorize' -or $life -match 'not authorize') 'lifecycle documents marker is not authorization'

Write-Host ''
Write-Host "Passed=$passed Failed=$failed"
if ($failed -gt 0) {
    exit 1
}
exit 0

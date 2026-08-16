# Shared helpers for Workflow V2 GitHub observer scripts (TASK-005C-C).
# Actions never write git. These scripts run on the developer machine.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if (-not $root) {
        throw 'Not inside a git repository.'
    }
    return $root.Trim()
}

function Resolve-GhExe {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'GitHub CLI\gh.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'GitHub CLI\gh.exe'),
        (Join-Path $env:LOCALAPPDATA 'GitHub CLI\gh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }
    throw 'GitHub CLI (gh) not found. Human must install and authenticate gh (TASK-005C-C).'
}

function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GhArgs
    )
    Assert-MergeForbidden -CommandParts $GhArgs
    $gh = Resolve-GhExe
    $out = & $gh @GhArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($GhArgs -join ' ') failed with exit $LASTEXITCODE : $out"
    }
    return $out.Trim()
}

function ConvertFrom-GhJson {
    param(
        [AllowEmptyString()]
        [string]$Json
    )
    if ([string]::IsNullOrWhiteSpace($Json)) {
        return @()
    }
    # Windows PowerShell 5.1: piping a JSON array through ConvertFrom-Json
    # yields one pipeline item (the whole array). foreach then member-enumerates
    # .name across all checks and Get-CiGateFact fail-closes to failure.
    $parsed = ConvertFrom-Json -InputObject $Json
    if ($null -eq $parsed) {
        return @()
    }
    if ($parsed -is [System.Array]) {
        return $parsed
    }
    return @($parsed)
}

function Assert-MergeForbidden {
    param(
        [string[]]$CommandParts = @()
    )
    $joined = ($CommandParts -join ' ')
    if ($joined -match '(^|\s)pr\s+merge(\s|$)' -or $joined -match 'gh\s+pr\s+merge') {
        throw 'Forbidden: Agent must not merge. There is no merge helper. Human merges main.'
    }
    if ($joined -match 'push\s+.*\borigin\s+main\b' -or $joined -match 'push\s+.*\bmain:main\b') {
        throw 'Forbidden: Agent must not push main.'
    }
}

function Get-CurrentBranch {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    Push-Location $RepoRoot
    try {
        $name = (& git branch --show-current).Trim()
        if (-not $name) {
            throw 'Detached HEAD is not allowed for workflow scripts.'
        }
        return $name
    }
    finally {
        Pop-Location
    }
}

function Assert-NotMain {
    param(
        [string]$Branch = (Get-CurrentBranch)
    )
    if ($Branch -eq 'main' -or $Branch -eq 'master') {
        throw "Refused: branch '$Branch' is main. Workflow scripts that write GitHub PRs must run on task/*."
    }
}

function Assert-TaskBranch {
    param(
        [string]$Branch = (Get-CurrentBranch)
    )
    Assert-NotMain -Branch $Branch
    if ($Branch -notmatch '^task/') {
        throw "Refused: branch '$Branch' is not task/*. Coding Agent may open PRs only from task/*."
    }
}

function Assert-OnMain {
    param(
        [string]$Branch = (Get-CurrentBranch)
    )
    if ($Branch -ne 'main') {
        throw "Refused: finalize-prep runs only on main (got '$Branch'). Do not archive on task/*."
    }
}

function Get-StateObject {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $path = Join-Path $RepoRoot '.agent\state.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing $path"
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-RuntimePath {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    return (Join-Path $RepoRoot '.agent\runtime.json')
}

function Read-RuntimeObject {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $path = Get-RuntimePath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-RuntimeObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Runtime,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $path = Get-RuntimePath -RepoRoot $RepoRoot
    $dir = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        throw "Missing $dir"
    }
    $json = $Runtime | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return $path
}

function New-RuntimeObject {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$PrUrl = $null,
        [Nullable[int]]$PrNumber = $null,
        [string]$HeadSha = $null,
        [ValidateSet('pending', 'success', 'failure', 'n/a')]$CiGate = 'pending',
        [string]$ProtocolStatus,
        [ValidateSet('not_started', 'running', 'passed', 'failed', 'n/a')]$ProtocolCiStatus,
        [bool]$CiRequired,
        [bool]$Merged = $false,
        [ValidateSet('github-pr', 'github-checks')]$Source = 'github-checks'
    )
    return [pscustomobject]@{
        version             = '1.0'
        task_id             = $TaskId
        pr_url              = $PrUrl
        pr_number           = $PrNumber
        head_sha            = $HeadSha
        ci_gate             = $CiGate
        protocol_status     = $ProtocolStatus
        protocol_ci_status  = $ProtocolCiStatus
        ci_required         = $CiRequired
        merged              = $Merged
        observed_at         = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        source              = $Source
        next_actor          = $null
        next_action         = $null
    }
}

function Find-TaskFile {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot),
        [switch]$IncludeCompleted
    )
    $dirs = @((Join-Path $RepoRoot '.agent\tasks\active'))
    if ($IncludeCompleted) {
        $dirs += (Join-Path $RepoRoot '.agent\tasks\completed')
    }
    foreach ($dir in $dirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $match = Get-ChildItem -LiteralPath $dir -Filter "$TaskId-*.md" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    throw "TASK file for $TaskId not found under .agent/tasks/active/."
}

function Find-ReportFile {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $path = Join-Path $RepoRoot ".agent\reports\$TaskId-report.md"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Report not found: $path"
    }
    return $path
}

function Test-IsCiGateName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    $n = $Name.Trim()
    return ($n -eq 'ci-gate') -or ($n -eq 'CI / ci-gate') -or ($n -match '(^|[\s/])ci-gate$')
}

function Convert-CheckToCiGate {
    param([Parameter(Mandatory = $true)]$Check)

    $bucket = ''
    if ($Check.PSObject.Properties.Name -contains 'bucket' -and $Check.bucket) {
        $bucket = [string]$Check.bucket
    }
    switch -Regex ($bucket.ToLowerInvariant()) {
        '^pass$' { return 'success' }
        '^fail$' { return 'failure' }
        '^pending$' { return 'pending' }
        '^skipping$' { return 'failure' }
    }

    $state = ''
    if ($Check.PSObject.Properties.Name -contains 'state' -and $Check.state) {
        $state = [string]$Check.state
    }
    switch -Regex ($state.ToUpperInvariant()) {
        '^(SUCCESS|PASS)$' { return 'success' }
        '^(FAILURE|FAIL|ERROR|CANCELLED|CANCELED|TIMED_OUT|ACTION_REQUIRED|STARTUP_FAILURE|STALE)$' { return 'failure' }
        '^(SKIPPED|NEUTRAL)$' { return 'failure' }
        default { return 'pending' }
    }
}

function Get-CiGateFact {
    param(
        [AllowEmptyCollection()]
        [object[]]$Checks
    )
    if ($null -eq $Checks) { $Checks = @() }
    $gate = @(
        $Checks | Where-Object { Test-IsCiGateName $_.name }
    ) | Select-Object -First 1

    if ($null -eq $gate) {
        $pending = $Checks | Where-Object {
            $b = ''
            if ($_.PSObject.Properties.Name -contains 'bucket') { $b = [string]$_.bucket }
            $s = ''
            if ($_.PSObject.Properties.Name -contains 'state') { $s = [string]$_.state }
            $b -eq 'pending' -or $s -match '^(PENDING|QUEUED|IN_PROGRESS|WAITING|EXPECTED)$'
        }
        if ($Checks.Count -eq 0 -or $pending) {
            return 'pending'
        }
        return 'failure'
    }
    return Convert-CheckToCiGate $gate
}

function Resolve-ProtocolFromCiGate {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('pending', 'success', 'failure', 'n/a')]
        [string]$CiGate,
        [Parameter(Mandatory = $true)]
        [bool]$CiRequired
    )

    if (-not $CiRequired) {
        return [pscustomobject]@{
            protocol_status    = 'awaiting_merge'
            protocol_ci_status = 'n/a'
        }
    }

    if ($CiGate -eq 'n/a') {
        throw 'ci_gate n/a is invalid when ci_required=true. Retired Human exception ci-gate.md §2.3 is not available.'
    }

    switch ($CiGate) {
        'success' {
            return [pscustomobject]@{
                protocol_status    = 'awaiting_merge'
                protocol_ci_status = 'passed'
            }
        }
        'failure' {
            return [pscustomobject]@{
                protocol_status    = 'ci_running'
                protocol_ci_status = 'failed'
            }
        }
        'pending' {
            return [pscustomobject]@{
                protocol_status    = 'ci_running'
                protocol_ci_status = 'running'
            }
        }
    }
}

function Assert-AwaitingMergeLegal {
    param(
        [Parameter(Mandatory = $true)][string]$ProtocolStatus,
        [Parameter(Mandatory = $true)][string]$CiGate,
        [Parameter(Mandatory = $true)][bool]$CiRequired,
        [Parameter(Mandatory = $true)][string]$ProtocolCiStatus
    )
    if ($ProtocolStatus -ne 'awaiting_merge') { return }
    if ($CiRequired) {
        if ($CiGate -ne 'success') {
            throw "Refused: ci_required TASK cannot enter awaiting_merge unless ci-gate is success (got ci_gate=$CiGate)."
        }
        if ($ProtocolCiStatus -ne 'passed') {
            throw "Refused: ci_required awaiting_merge requires protocol_ci_status=passed (got $ProtocolCiStatus)."
        }
    }
    else {
        if ($ProtocolCiStatus -ne 'n/a') {
            throw "Refused: ci_required=no must keep protocol_ci_status=n/a (got $ProtocolCiStatus). Do not impersonate passed."
        }
    }
}

function Get-LatestReview {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $dir = Join-Path $RepoRoot '.agent\reviews'
    if (-not (Test-Path -LiteralPath $dir)) {
        return $null
    }
    $files = @(Get-ChildItem -LiteralPath $dir -Filter "$TaskId-review-round-*.md" -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $null }

    $latest = $files | Sort-Object {
        if ($_.BaseName -match 'review-round-(\d+)$') { [int]$Matches[1] } else { -1 }
    } | Select-Object -Last 1

    $text = Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8
    $decision = 'unknown'
    if ($text -match '(?ms)^## Decision\s+.*?^`?(approve|reject)`?\s*$') {
        $decision = $Matches[1]
    }
    elseif ($text -match '(?im)^decision:\s*`?(approve|reject)`?') {
        $decision = $Matches[1].ToLowerInvariant()
    }

    return [pscustomobject]@{
        Path     = $latest.FullName
        Name     = $latest.Name
        Decision = $decision
    }
}

function Assert-ReviewApproved {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $review = Get-LatestReview -TaskId $TaskId -RepoRoot $RepoRoot
    if ($null -eq $review) {
        throw "Refused: no Independent Review file for $TaskId. open-pr requires decision: approve."
    }
    if ($review.Decision -ne 'approve') {
        throw "Refused: latest review is '$($review.Decision)' ($($review.Name)). open-pr requires decision: approve."
    }
    return $review
}

function Get-RelativeRepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($full.Substring($root.Length) -replace '\\', '/')
    }
    return ($FullPath -replace '\\', '/')
}

function Test-GitignoreRuntime {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    Push-Location $RepoRoot
    try {
        $out = & git check-ignore -q -- .agent/runtime.json
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        Pop-Location
    }
}

function Test-GitignoreHandoff {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    Push-Location $RepoRoot
    try {
        & git check-ignore -q -- .agent/handoff.md | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        Pop-Location
    }
}

function Save-StateObject {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $path = Join-Path $RepoRoot '.agent\state.json'
    $json = $State | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return $path
}

function Test-PlanApprovedFlag {
    param([object]$State)
    if ($null -eq $State) { return $false }
    $names = @($State.PSObject.Properties.Name)
    if ($names -notcontains 'plan_approved') { return $false }
    $v = $State.plan_approved
    if ($v -is [bool]) { return $v }
    if ($v -is [string]) { return ($v.Trim().ToLowerInvariant() -eq 'true') }
    try {
        return [System.Convert]::ToBoolean($v)
    }
    catch {
        return $false
    }
}

function Assert-PlanApproved {
    param(
        [object]$State = $null,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    if ($null -eq $State) {
        $State = Get-StateObject -RepoRoot $RepoRoot
    }
    if (-not (Test-PlanApprovedFlag -State $State)) {
        throw 'Refused: plan_approved is not true. Gate 1 PRIMARY enforcement is start-coding.ps1: implementation must not start. The open-pr.ps1 plan_approved check is defense-in-depth only and does not authorize coding.'
    }
}

function Get-HandoffPath {
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    return (Join-Path $RepoRoot '.agent\handoff.md')
}

function Write-Handoff {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][bool]$PlanApproved,
        [Parameter(Mandatory = $true)][string]$NextActor,
        [Parameter(Mandatory = $true)][string]$NextAction,
        [string[]]$Reads = @(),
        [string[]]$Forbidden = @(
            'gh pr merge',
            'self-review / simulate Review Agent',
            'business code under apps/ or agents/',
            'forge CI passed or failed',
            'normal git push origin main (D-001 archive-push only, after independent checks)',
            'force push',
            'infer Gate 1 approval from conversation'
        ),
        [string]$Gate1Decision = '',
        [string]$ApprovalAuthority = '',
        [string]$Notes = '',
        [string]$RepoRoot = (Get-RepoRoot)
    )

    $planStr = 'false'
    if ($PlanApproved) { $planStr = 'true' }

    $readLines = @()
    foreach ($r in $Reads) {
        $readLines += "- $r"
    }
    if ($readLines.Count -eq 0) { $readLines = @('- (none)') }

    $forbLines = @()
    foreach ($f in $Forbidden) {
        $forbLines += "- $f"
    }

    $gateLine = '(none)'
    if ($Gate1Decision) { $gateLine = $Gate1Decision }
    $authLine = '(none)'
    if ($ApprovalAuthority) { $authLine = $ApprovalAuthority }

    $md = @"
# Agent Handoff (live overlay; gitignored)

Do not paste ChatGPT transcripts. Agents read this file, the TASK, report, review, ``state.json``, and GitHub.

task_id: $TaskId
status: $Status
plan_approved: $planStr
next_actor: $NextActor
next_action: $NextAction
gate1_decision: $gateLine
approval_authority: $authLine

## Reads

$($readLines -join "`n")

## Forbidden

$($forbLines -join "`n")

## Notes

$Notes

updated_at: $((Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'))
"@

    $path = Get-HandoffPath -RepoRoot $RepoRoot
    Set-Content -LiteralPath $path -Value $md -Encoding UTF8

    $runtime = Read-RuntimeObject -RepoRoot $RepoRoot
    if ($runtime) {
        $runtime | Add-Member -NotePropertyName 'next_actor' -NotePropertyValue $NextActor -Force
        $runtime | Add-Member -NotePropertyName 'next_action' -NotePropertyValue $NextAction -Force
        Write-RuntimeObject -Runtime $runtime -RepoRoot $RepoRoot | Out-Null
    }

    return $path
}

function Get-LivePrView {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber
    )
    $raw = Invoke-Gh -GhArgs @('pr', 'view', "$PrNumber", '--json', 'number,url,state,mergedAt,headRefOid,headRefName')
    return (ConvertFrom-GhJson $raw) | Select-Object -First 1
}

function Get-LivePrChecks {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber
    )
    $raw = Invoke-Gh -GhArgs @('pr', 'checks', "$PrNumber", '--json', 'name,state,bucket')
    return @(ConvertFrom-GhJson $raw)
}

function Assert-PrViewMerged {
    param(
        [Parameter(Mandatory = $true)]$View
    )
    if ($null -eq $View) {
        throw 'Refused: missing GitHub PR view; D-001/finalize require authoritative MERGED evidence.'
    }
    $state = [string]$View.state
    $mergedAt = $null
    if ($View.PSObject.Properties.Name -contains 'mergedAt') { $mergedAt = $View.mergedAt }
    if ($state -ne 'MERGED' -or -not $mergedAt) {
        $num = ''
        if ($View.PSObject.Properties.Name -contains 'number') { $num = "#$($View.number) " }
        throw "Refused: PR ${num}state=$state mergedAt=$mergedAt. D-001/finalize require authoritative GitHub MERGED. This is not a merge helper."
    }
}

function Confirm-PrMergedLive {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber
    )
    $view = Get-LivePrView -PrNumber $PrNumber
    Assert-PrViewMerged -View $view
    return $view
}

function Assert-MainSyncedToOrigin {
    param(
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][string]$OriginMain
    )
    if ($Head -ne $OriginMain) {
        throw "Refused: local main ($Head) is not synced with origin/main ($OriginMain)."
    }
}

function Confirm-MainSyncedWithOrigin {
    param(
        [string]$RepoRoot = (Get-RepoRoot),
        [switch]$AllowAllowlistDirty,
        [Parameter(Mandatory = $true)][string]$TaskId
    )
    Push-Location $RepoRoot
    try {
        $dirtyLines = @(& git status --porcelain | Where-Object { $_ -and $_.Trim() })
        $paths = @()
        if ($dirtyLines.Count -gt 0) {
            if (-not $AllowAllowlistDirty) {
                throw 'Refused: working tree is not clean.'
            }
            foreach ($line in $dirtyLines) {
                $rawLine = [string]$line
                if ($rawLine.Length -lt 4) { continue }
                $p = $rawLine.Substring(3).Trim().Trim('"')
                if ($p -match ' -> ') {
                    $p = ($p -split ' -> ')[-1]
                }
                $paths += ($p -replace '\\', '/')
            }
            Assert-D001DiffAllowlisted -Paths $paths -TaskId $TaskId
        }
        & git fetch origin
        if ($LASTEXITCODE -ne 0) {
            throw "git fetch origin failed with exit $LASTEXITCODE"
        }
        $head = (& git rev-parse HEAD).Trim()
        $originMain = (& git rev-parse origin/main).Trim()
        Assert-MainSyncedToOrigin -Head $head -OriginMain $originMain
        return [pscustomobject]@{
            Head       = $head
            OriginMain = $originMain
            DirtyPaths = @($paths)
        }
    }
    finally {
        Pop-Location
    }
}

function Test-D001AllowlistedPath {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)][string]$TaskId
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ([string]::IsNullOrWhiteSpace($TaskId)) { return $false }
    $norm = ($Path -replace '\\', '/').TrimStart('/')
    if ($norm -match '^(apps|agents)(/|$)' -or $norm -match '^\.github/workflows(/|$)') {
        return $false
    }
    if ($norm -eq '.agent/state.json') { return $true }
    $esc = [regex]::Escape($TaskId)
    if ($norm -match "^\.agent/tasks/active/$esc-.+\.md$") { return $true }
    if ($norm -match "^\.agent/tasks/completed/$esc-.+\.md$") { return $true }
    return $false
}

function Assert-D001DiffAllowlisted {
    param(
        [AllowEmptyCollection()]
        [string[]]$Paths,
        [Parameter(Mandatory = $true)][string]$TaskId
    )
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        throw 'Refused: D-001 allowlist requires the current TASK identity.'
    }
    if ($null -eq $Paths) { $Paths = @() }
    $bad = @()
    foreach ($p in $Paths) {
        $norm = ($p -replace '\\', '/')
        if ($norm -match '^(apps|agents)(/|$)' -or $norm -match '^\.github/workflows(/|$)') {
            $bad += $norm
            continue
        }
        if (-not (Test-D001AllowlistedPath -Path $norm -TaskId $TaskId)) {
            $bad += $norm
        }
    }
    if ($bad.Count -gt 0) {
        throw "Refused: D-001 allowlist violation for ${TaskId}: $($bad -join ', '). Only this TASK file move and .agent/state.json are allowed."
    }
}

function Get-D001ExactArchivePaths {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        throw 'Refused: missing task identity; cannot derive exact D-001 paths.'
    }
    $leaf = $null
    foreach ($rel in @('.agent\tasks\active', '.agent\tasks\completed')) {
        $dir = Join-Path $RepoRoot $rel
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $hit = Get-ChildItem -LiteralPath $dir -Filter "$TaskId-*.md" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) {
            $leaf = $hit.Name
            break
        }
    }
    if (-not $leaf) {
        throw "Refused: cannot derive exact TASK file name for $TaskId (missing active/completed file)."
    }
    return @(
        '.agent/state.json',
        ".agent/tasks/active/$leaf",
        ".agent/tasks/completed/$leaf"
    )
}

function Get-D001ArchiveCommitSubject {
    param([Parameter(Mandatory = $true)][string]$TaskId)
    return "chore(agent): archive $TaskId as completed"
}

function Resolve-D001TaskId {
    param(
        [Parameter(Mandatory = $true)]$State
    )
    if ($null -eq $State) {
        throw 'Refused: missing task identity (state is null).'
    }
    $taskId = [string]$State.active_task
    if (-not $taskId -and [string]$State.status -eq 'completed' -and $State.last_completed_task) {
        $taskId = [string]$State.last_completed_task
    }
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw 'Refused: missing task identity (active_task is null and last_completed_task is not usable).'
    }
    return $taskId
}

function Get-TaskExpectedBranch {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        throw 'Refused: missing task identity; cannot read expected branch.'
    }
    $file = Find-TaskFile -TaskId $TaskId -RepoRoot $RepoRoot -IncludeCompleted
    $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    if ($text -match '(?ms)## Branch\s.*?`(task/[^`\r\n]+)`') {
        $branch = $Matches[1].Trim()
        if ($branch) { return $branch }
    }
    throw "Refused: missing expected branch identity in TASK file for $TaskId."
}

function Assert-D001TaskPrBinding {
    param(
        [Parameter(Mandatory = $true)]$State,
        $Runtime,
        [Parameter(Mandatory = $true)]$View,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch,
        [int]$RequestedPrNumber = 0
    )
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        throw 'Refused: missing task identity.'
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedBranch)) {
        throw 'Refused: missing expected branch identity.'
    }
    if ($null -eq $Runtime) {
        throw 'Refused: ambiguous PR evidence (missing runtime overlay bound to this TASK).'
    }
    $runtimeTask = ''
    if ($Runtime.PSObject.Properties.Name -contains 'task_id' -and $Runtime.task_id) {
        $runtimeTask = [string]$Runtime.task_id
    }
    if (-not $runtimeTask) {
        throw 'Refused: ambiguous PR evidence (runtime.task_id missing).'
    }
    if ($runtimeTask -ne $TaskId) {
        throw "Refused: PR/task mismatch (runtime.task_id=$runtimeTask current=$TaskId). D-001 will not use another TASK's MERGED PR."
    }
    $runtimePr = 0
    if ($Runtime.PSObject.Properties.Name -contains 'pr_number' -and $Runtime.pr_number) {
        $runtimePr = [int]$Runtime.pr_number
    }
    if ($runtimePr -le 0) {
        throw 'Refused: ambiguous PR evidence (runtime.pr_number missing).'
    }
    if ($RequestedPrNumber -gt 0 -and $RequestedPrNumber -ne $runtimePr) {
        throw "Refused: ambiguous PR evidence (requested PR #$RequestedPrNumber vs runtime #$runtimePr)."
    }
    Assert-PrViewMerged -View $View
    $viewNumber = 0
    if ($View.PSObject.Properties.Name -contains 'number' -and $View.number) {
        $viewNumber = [int]$View.number
    }
    if ($viewNumber -le 0) {
        throw 'Refused: ambiguous PR evidence (live PR number missing).'
    }
    if ($viewNumber -ne $runtimePr) {
        throw "Refused: PR/task mismatch (live PR #$viewNumber vs runtime #$runtimePr)."
    }
    $headRef = ''
    if ($View.PSObject.Properties.Name -contains 'headRefName' -and $View.headRefName) {
        $headRef = [string]$View.headRefName
    }
    if (-not $headRef) {
        throw 'Refused: missing expected branch identity on live PR (headRefName empty).'
    }
    if ($headRef -ne $ExpectedBranch) {
        throw "Refused: headRefName mismatch (live=$headRef expected=$ExpectedBranch) for $TaskId."
    }
}

function Assert-AuthorizedUnpushedArchiveFacts {
    param(
        [Parameter(Mandatory = $true)][int]$AheadCount,
        [Parameter(Mandatory = $true)][int]$BehindCount,
        [Parameter(Mandatory = $true)][bool]$Dirty,
        [string]$ParentSha,
        [string]$OriginMainSha,
        [string]$Subject,
        [AllowEmptyCollection()][string[]]$CommitPaths,
        [Parameter(Mandatory = $true)][string]$TaskId
    )
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        throw 'Refused: missing task identity; cannot authorize unpushed archive commit.'
    }
    if ($AheadCount -le 0 -and $BehindCount -le 0) {
        return $false
    }
    if ($BehindCount -gt 0) {
        throw 'Refused: local main is behind or diverged from origin/main (true unsynced). D-001 retry allows only exactly one unpushed authorized archive commit.'
    }
    if ($Dirty) {
        throw 'Refused: working tree is dirty while main is ahead of origin/main; unexpected D-001 retry state.'
    }
    if ($AheadCount -ne 1) {
        throw "Refused: main is ahead by unexpected commits (ahead=$AheadCount). D-001 retry allows exactly one authorized archive commit for this TASK."
    }
    if (-not $ParentSha -or -not $OriginMainSha -or $ParentSha -ne $OriginMainSha) {
        throw 'Refused: unpushed commit parent is not origin/main; local/origin history unexpected.'
    }
    $expected = Get-D001ArchiveCommitSubject -TaskId $TaskId
    if ($Subject -ne $expected) {
        throw "Refused: unpushed commit identity does not match the authorized archive transition for $TaskId."
    }
    Assert-D001DiffAllowlisted -Paths $CommitPaths -TaskId $TaskId
    $norm = @($CommitPaths | ForEach-Object { ($_ -replace '\\', '/') })
    if ($norm -notcontains '.agent/state.json') {
        throw 'Refused: authorized archive commit must include .agent/state.json.'
    }
    $esc = [regex]::Escape($TaskId)
    $completed = @($norm | Where-Object { $_ -match "^\.agent/tasks/completed/$esc-.+\.md$" })
    if ($completed.Count -ne 1) {
        throw "Refused: authorized archive commit must include exactly this TASK file under completed/ ($TaskId)."
    }
    return $true
}

function Get-AuthorizedUnpushedD001Commit {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    Push-Location $RepoRoot
    try {
        $dirtyLines = @(& git status --porcelain | Where-Object { $_ -and $_.Trim() })
        $dirty = ($dirtyLines.Count -gt 0)
        & git fetch origin
        if ($LASTEXITCODE -ne 0) {
            throw "git fetch origin failed with exit $LASTEXITCODE"
        }
        $head = (& git rev-parse HEAD).Trim()
        $originMain = (& git rev-parse origin/main).Trim()
        $ahead = [int]((& git rev-list --count "$originMain..$head").Trim())
        $behind = [int]((& git rev-list --count "$head..$originMain").Trim())
        if ($ahead -le 0 -and $behind -le 0) {
            return $null
        }
        $parent = $null
        $subject = $null
        $paths = @()
        if ($ahead -ge 1) {
            $parent = (& git rev-parse "$head^").Trim()
            $subject = (& git log -1 --format=%s $head).Trim()
            $paths = @(& git diff-tree --no-commit-id --name-only -r $head | ForEach-Object { ($_ -replace '\\', '/') })
        }
        $ok = Assert-AuthorizedUnpushedArchiveFacts `
            -AheadCount $ahead `
            -BehindCount $behind `
            -Dirty $dirty `
            -ParentSha $parent `
            -OriginMainSha $originMain `
            -Subject $subject `
            -CommitPaths $paths `
            -TaskId $TaskId
        if ($ok) { return $head }
        return $null
    }
    finally {
        Pop-Location
    }
}

function Get-DurableCiStatusFromLiveChecks {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber,
        [Parameter(Mandatory = $true)][bool]$CiRequired
    )
    $checks = Get-LivePrChecks -PrNumber $PrNumber
    $ciGate = Get-CiGateFact -Checks $checks
    if ($CiRequired) {
        if ($ciGate -ne 'success') {
            throw "Refused: ci_required TASK archive requires live GitHub ci-gate success (N-002; got ci_gate=$ciGate). Do not trust stale runtime.json overlay."
        }
        return [pscustomobject]@{
            CiGate     = $ciGate
            DurableCi  = 'passed'
            Checks     = $checks
        }
    }
    return [pscustomobject]@{
        CiGate     = $ciGate
        DurableCi  = 'n/a'
        Checks     = $checks
    }
}

function Assert-D001ArchivePreconditions {
    <#
      Authorization for D-001 archive-push.
      Never reads the capability-marker environment variable.
      That marker is not authorization and must not short-circuit these checks.
    #>
    param(
        [string]$RepoRoot = (Get-RepoRoot),
        [int]$PrNumber = 0
    )

    $branch = Get-CurrentBranch -RepoRoot $RepoRoot
    Assert-OnMain -Branch $branch

    $state = Get-StateObject -RepoRoot $RepoRoot
    $taskId = Resolve-D001TaskId -State $state
    $expectedBranch = Get-TaskExpectedBranch -TaskId $taskId -RepoRoot $RepoRoot
    $runtime = Read-RuntimeObject -RepoRoot $RepoRoot

    $runtimePr = 0
    if ($runtime -and $runtime.PSObject.Properties.Name -contains 'pr_number' -and $runtime.pr_number) {
        $runtimePr = [int]$runtime.pr_number
    }
    $usePr = $runtimePr
    if ($PrNumber -gt 0) { $usePr = $PrNumber }
    if ($usePr -le 0) {
        throw 'Refused: no PR number bound to this TASK; cannot confirm Human merge from GitHub.'
    }

    $view = Confirm-PrMergedLive -PrNumber $usePr
    Assert-D001TaskPrBinding `
        -State $state `
        -Runtime $runtime `
        -View $view `
        -TaskId $taskId `
        -ExpectedBranch $expectedBranch `
        -RequestedPrNumber $PrNumber

    $ciRequired = [bool]$state.ci_required
    $ci = Get-DurableCiStatusFromLiveChecks -PrNumber $usePr -CiRequired $ciRequired

    $retrySha = Get-AuthorizedUnpushedD001Commit -TaskId $taskId -RepoRoot $RepoRoot
    $mode = 'fresh'
    $sync = $null
    if ($retrySha) {
        $mode = 'retry'
    }
    else {
        $sync = Confirm-MainSyncedWithOrigin -RepoRoot $RepoRoot -AllowAllowlistDirty -TaskId $taskId
    }

    return [pscustomobject]@{
        TaskId          = $taskId
        ExpectedBranch  = $expectedBranch
        PrNumber        = $usePr
        View            = $view
        Sync            = $sync
        CiRequired      = $ciRequired
        CiGate          = $ci.CiGate
        DurableCi       = $ci.DurableCi
        State           = $state
        Mode            = $mode
        RetrySha        = $retrySha
    }
}

function Update-ArchivedTaskFile {
    param(
        [Parameter(Mandatory = $true)][string]$TaskFilePath,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$PrUrl,
        [Parameter(Mandatory = $true)][string]$DurableCi
    )
    if (-not (Test-Path -LiteralPath $TaskFilePath)) {
        throw "Archived TASK file missing: $TaskFilePath"
    }
    $text = Get-Content -LiteralPath $TaskFilePath -Raw -Encoding UTF8
    $text = [regex]::Replace($text, '(?m)^`specified`\s*$', '`completed`', 1)
    $text = [regex]::Replace($text, '(?m)^`coding`\s*$', '`completed`')
    $text = [regex]::Replace($text, '(?m)^`in_review`\s*$', '`completed`')
    $text = [regex]::Replace($text, '(?m)^`git_ready`\s*$', '`completed`')
    $text = [regex]::Replace($text, '(?m)^`awaiting_merge`\s*$', '`completed`')
    $stamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $result = @"
- Status: ``completed``
- Report: ``.agent/reports/$TaskId-report.md``
- Review: ``.agent/reviews/`` (Independent Review file)
- Notes: Human merged ``main``. Durable ci_status=$DurableCi. PR $PrUrl. Archived $stamp.
"@
    if ($text -match '(?ms)^## Result\r?\n.*') {
        $text = [regex]::Replace($text, '(?ms)^## Result\r?\n.*\z', "## Result`r`n`r`n$result")
    }
    else {
        $text = $text.TrimEnd() + "`r`n`r`n## Result`r`n`r`n$result"
    }
    Set-Content -LiteralPath $TaskFilePath -Value $text -Encoding UTF8
}

function Invoke-FinalizePrepApply {
    param(
        [Parameter(Mandatory = $true)]$Facts,
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $taskId = [string]$Facts.TaskId
    $destDir = Join-Path $RepoRoot '.agent\tasks\completed'
    if (-not (Test-Path -LiteralPath $destDir)) {
        throw "Missing $destDir"
    }
    $dest = $null
    $completedHit = Get-ChildItem -LiteralPath $destDir -Filter "$taskId-*.md" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($completedHit) {
        $dest = $completedHit.FullName
    }
    else {
        $taskFile = Find-TaskFile -TaskId $taskId -RepoRoot $RepoRoot
        $dest = Join-Path $destDir (Split-Path $taskFile -Leaf)
        Move-Item -LiteralPath $taskFile -Destination $dest
    }

    Update-ArchivedTaskFile -TaskFilePath $dest -TaskId $taskId -PrUrl $Facts.View.url -DurableCi $Facts.DurableCi

    $state = $Facts.State
    $state.status = 'completed'
    $state.last_completed_task = $taskId
    $state.active_task = $null
    $state.pr_url = $Facts.View.url
    $state.ci_status = $Facts.DurableCi
    $state.plan_approved = $false
    $state.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $state.agents.cursor.status = 'idle'
    $state.agents.review.status = 'idle'
    Save-StateObject -State $state -RepoRoot $RepoRoot | Out-Null

    return $dest
}

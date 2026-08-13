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

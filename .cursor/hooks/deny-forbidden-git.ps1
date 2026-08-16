# Defense-in-depth: deny gh pr merge and unauthorized git push to main.
# Always print JSON to stdout so failClosed cannot brick unrelated commands.
# AGENT_D001_ARCHIVE=1 is a capability marker only — it does NOT authorize push.
$ErrorActionPreference = 'Continue'

function Write-HookResult {
    param(
        [string]$Permission = 'allow',
        [string]$UserMessage = '',
        [string]$AgentMessage = ''
    )
    if ($Permission -ne 'deny' -and $Permission -ne 'ask') { $Permission = 'allow' }
    $json = '{"permission":"' + $Permission + '"'
    if ($UserMessage) {
        $esc = $UserMessage.Replace('\', '\\').Replace('"', '\"')
        $json += ',"user_message":"' + $esc + '"'
    }
    if ($AgentMessage) {
        $esc2 = $AgentMessage.Replace('\', '\\').Replace('"', '\"')
        $json += ',"agent_message":"' + $esc2 + '"'
    }
    $json += '}'
    [Console]::Out.WriteLine($json)
}

try {
    $raw = ''
    try { $raw = [Console]::In.ReadToEnd() } catch { $raw = '' }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-HookResult -Permission 'allow'
        exit 0
    }

    $command = ''
    try {
        $payload = $raw | ConvertFrom-Json
        if ($payload -and $payload.command) { $command = [string]$payload.command }
    }
    catch {
        Write-HookResult -Permission 'allow' -AgentMessage 'hook stdin was not JSON; allowing non-parseable event'
        exit 0
    }

    if ($command -match '(^|\s)gh(\s|\.exe\s).*\bpr\s+merge\b' -or $command -match '\bpr\s+merge\b') {
        Write-HookResult -Permission 'deny' `
            -UserMessage 'Forbidden: gh pr merge. Only Human merges main.' `
            -AgentMessage 'Hook denied merge. There is no merge helper. Human Gate 2 only.'
        exit 0
    }

    $isForce = ($command -match '(^|\s)--force(-with-lease)?(\s|$)' -or $command -match '(^|\s)-f(\s|$)')
    $pushesMain = ($command -match 'git(\.exe)?\s+push\b' -and (
            $command -match '\borigin\s+main\b' -or
            $command -match '\bmain:main\b' -or
            $command -match '\bHEAD:main\b'
        ))

    if ($pushesMain -and $isForce) {
        Write-HookResult -Permission 'deny' `
            -UserMessage 'Forbidden: force push to main.' `
            -AgentMessage 'Hook denied force push. D-001 never force-pushes.'
        exit 0
    }

    if ($pushesMain) {
        $marker = [string]$env:AGENT_D001_ARCHIVE
        if ($marker -ne '1') {
            Write-HookResult -Permission 'deny' `
                -UserMessage 'Forbidden: git push to main without D-001 archive-push path.' `
                -AgentMessage 'Hook denied push to main. AGENT_D001_ARCHIVE is not set. Marker alone would still not be authorization; archive-push.ps1 must independently verify all D-001 preconditions.'
            exit 0
        }
        Write-HookResult -Permission 'allow' `
            -AgentMessage 'Capability marker present for non-force push origin main. Marker is not authorization; archive-push independent checks are.'
        exit 0
    }

    Write-HookResult -Permission 'allow'
    exit 0
}
catch {
    Write-HookResult -Permission 'allow' -AgentMessage 'hook catch: allow unrelated command after internal error'
    exit 0
}

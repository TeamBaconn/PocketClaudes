#requires -Version 5.1
<#
.SYNOPSIS
  Hook entry point for Windows. Reads Claude Code hook JSON from stdin,
  builds a flat IpcCommand, and delivers it to the running PocketClaudes game.
#>
[CmdletBinding()]
param()

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try {
    $hook = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$GamePort = 1604

function Get-HostPid {
    $currentPid = $PID
    for ($i = 0; $i -lt 12; $i++) {
        try {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $currentPid" -ErrorAction Stop
        } catch {
            break
        }
        if (-not $proc -or -not $proc.ParentProcessId) { break }
        $parentId = [int]$proc.ParentProcessId
        $parent = Get-Process -Id $parentId -ErrorAction SilentlyContinue
        if (-not $parent) { break }
        if ($parent.MainWindowHandle -ne 0) { return $parent.Id }
        $currentPid = $parentId
    }
    return 0
}

$command = [ordered]@{
    v                = 1
    eventName        = [string]$hook.hook_event_name
    sessionId        = [string]$hook.session_id
    agentId          = [string]$hook.agent_id
    agentType        = [string]$hook.agent_type
    toolName         = [string]$hook.tool_name
    toolUseId        = [string]$hook.tool_use_id
    model            = [string]$hook.model
    hostPid          = Get-HostPid
    cwd              = [string]$hook.cwd
}
$json = $command | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$GamePort/" -Method Post `
        -Body $json -ContentType 'application/json' -TimeoutSec 2 | Out-Null
} catch {
    Write-Verbose "POST to port $GamePort failed: $($_.Exception.Message)"
}

exit 0

<#
.SYNOPSIS
Links the GlazeWM config for a layout, reloads it, and moves every open workspace to the monitor that layout binds it to.

.DESCRIPTION
GlazeWM applies bind_to_monitor only when it creates a workspace, so a reload alone leaves open workspaces where they
are. A workspace the linked config does not bind goes to monitor 0, which is how Single gathers everything onto one
monitor. Monitor indexes follow GlazeWM's own order, the order of `glazewm query monitors`.
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Single', 'Dual')]
    [string]$Layout
)

$ErrorActionPreference = 'Stop'

class GlazeMonitor {
    [int]$Index
    [string]$Id
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [string[]]$WorkspaceNames
}

function Invoke-GlazeWm([string[]]$arguments) {
    $output = & glazewm @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "glazewm $($arguments -join ' ') exited ${LASTEXITCODE}: $output"
    }
    $reply = $output | ConvertFrom-Json
    if (-not $reply.success) {
        throw "glazewm $($arguments -join ' ') failed: $($reply.error)"
    }
    return $reply.data
}

function Get-GlazeMonitor {
    $monitors = (Invoke-GlazeWm @('query', 'monitors')).monitors
    [GlazeMonitor[]]$result = for ($index = 0; $index -lt $monitors.Count; $index++) {
        $monitor = $monitors[$index]
        [GlazeMonitor]@{
            Index          = $index
            Id             = $monitor.id
            X              = $monitor.x
            Y              = $monitor.y
            Width          = $monitor.width
            Height         = $monitor.height
            WorkspaceNames = @($monitor.children | Where-Object type -EQ 'workspace' | ForEach-Object name)
        }
    }
    return $result
}

function Get-FocusedWorkspaceName {
    $workspaces = (Invoke-GlazeWm @('query', 'workspaces')).workspaces
    return ($workspaces | Where-Object hasFocus | Select-Object -First 1).name
}

function Get-WorkspaceBinding([string]$configPath) {
    # Line-based because the configs keep each bind_to_monitor directly under its workspace name.
    [hashtable]$bindings = @{}
    [string]$name = $null
    foreach ($line in Get-Content $configPath) {
        if ($line -match "^\s*-\s*name:\s*'([^']+)'") {
            $name = $Matches[1]
        }
        elseif ($name -and $line -match '^\s*bind_to_monitor:\s*(\d+)') {
            $bindings[$name] = [int]$Matches[1]
        }
    }
    return $bindings
}

function Get-MoveDirection([GlazeMonitor]$from, [GlazeMonitor]$to) {
    if ($to.X -ge $from.X + $from.Width) { return 'right' }
    if ($to.X + $to.Width -le $from.X) { return 'left' }
    if ($to.Y -ge $from.Y + $from.Height) { return 'down' }
    return 'up'
}

function Select-Workspace([string]$name) {
    # toggle_workspace_on_refocus sends a focus of the focused workspace back to the previous one.
    if ((Get-FocusedWorkspaceName) -ne $name) {
        Invoke-GlazeWm @('command', 'focus', '--workspace', $name) | Out-Null
    }
}

function Move-Workspace([string]$name, [int]$targetIndex) {
    [GlazeMonitor[]]$monitors = Get-GlazeMonitor
    for ($step = 0; $step -lt $monitors.Count; $step++) {
        $current = $monitors | Where-Object { $_.WorkspaceNames -contains $name }
        if (-not $current) {
            throw "workspace $name is on no monitor"
        }
        if ($current.Index -eq $targetIndex) {
            return
        }
        Select-Workspace $name
        $direction = Get-MoveDirection $current $monitors[$targetIndex]
        Invoke-GlazeWm @('command', 'move-workspace', '--direction', $direction) | Out-Null
        $monitors = Get-GlazeMonitor
    }
    throw "workspace $name did not reach monitor $targetIndex after $($monitors.Count) moves"
}

$config = Join-Path $PSScriptRoot "config_$($Layout.ToLower()).yaml"
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.glzr\glazewm\config.yaml" -Target $config | Out-Null
Invoke-GlazeWm @('command', 'wm-reload-config') | Out-Null

$bindings = Get-WorkspaceBinding $config
[GlazeMonitor[]]$monitors = Get-GlazeMonitor
[System.Collections.Specialized.OrderedDictionary]$targets = [ordered]@{}
foreach ($name in @($monitors.WorkspaceNames)) {
    $target = if ($bindings.ContainsKey($name)) { $bindings[$name] } else { 0 }
    if ($target -ge $monitors.Count) {
        throw "$Layout binds workspace $name to monitor $target, but only $($monitors.Count) monitors are connected"
    }
    $targets[$name] = $target
}

$focused = Get-FocusedWorkspaceName
foreach ($entry in $targets.GetEnumerator()) {
    Move-Workspace $entry.Key $entry.Value
}
Select-Workspace $focused

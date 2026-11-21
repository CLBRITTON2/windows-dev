<#
.SYNOPSIS
Starts Claude Code in the pane of a tab the user just opened in herdr.

.DESCRIPTION
herdr runs this on tab.created. A tab made with `herdr tab create --no-focus` (a script or an agent testing a command in
a spare pane) arrives unfocused and keeps its shell.
#>

$ErrorActionPreference = 'Stop'

$tab = ($env:HERDR_PLUGIN_EVENT_JSON | ConvertFrom-Json).data.tab
if (-not $tab.focused) {
    return
}

$output = & $env:HERDR_BIN_PATH pane list --workspace $tab.workspace_id
if ($LASTEXITCODE -ne 0) {
    throw "herdr pane list --workspace $($tab.workspace_id) exited ${LASTEXITCODE}: $output"
}
$panes = @(($output | ConvertFrom-Json).result.panes | Where-Object tab_id -eq $tab.tab_id)
if ($panes.Count -ne 1) {
    throw "herdr pane list has $($panes.Count) panes in new tab $($tab.tab_id), want 1: $output"
}

$output = & $env:HERDR_BIN_PATH agent list
if ($LASTEXITCODE -ne 0) {
    throw "herdr agent list exited ${LASTEXITCODE}: $output"
}
# herdr refuses an agent name another pane already holds
[string[]]$takenNames = @(($output | ConvertFrom-Json).result.agents.name)
[string]$name = 'claude'
[int]$number = 1
while ($takenNames -contains $name) {
    $number++
    $name = "claude-$number"
}

$output = & $env:HERDR_BIN_PATH agent start $name --kind claude --pane $panes[0].pane_id
if ($LASTEXITCODE -ne 0) {
    throw "herdr agent start $name --pane $($panes[0].pane_id) exited ${LASTEXITCODE}: $output"
}

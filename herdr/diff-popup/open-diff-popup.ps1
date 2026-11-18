<#
.SYNOPSIS
Opens the diff popup once the calling herdr pane (HERDR_PANE_ID) is the focused one. herdr opens a popup plugin pane
on the active pane only, so opening it while the user is in another pane would cover that pane instead.
#>
param(
    [Parameter(Mandatory)][string]$OldPath,
    [Parameter(Mandatory)][string]$NewPath,
    [Parameter(Mandatory)][string]$NotePath,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][int]$FocusPollIntervalMs
)

$ErrorActionPreference = 'Stop'

if (-not $env:HERDR_PANE_ID) {
    throw 'HERDR_PANE_ID is not set: run this from a herdr pane'
}

while ($true) {
    $paneListJson = herdr pane list
    if ($LASTEXITCODE -ne 0) {
        throw "herdr pane list failed (exit $LASTEXITCODE): $paneListJson"
    }
    $focusedPane = (($paneListJson | ConvertFrom-Json).result.panes | Where-Object { $_.focused }).pane_id
    if ($focusedPane -eq $env:HERDR_PANE_ID) {
        break
    }
    Start-Sleep -Milliseconds $FocusPollIntervalMs
}

herdr plugin pane open --plugin windows-dev.diff-popup --entrypoint diff --env "DIFF_OLD_PATH=$OldPath" `
    --env "DIFF_NEW_PATH=$NewPath" --env "DIFF_NOTE_PATH=$NotePath" --env "DIFF_LABEL=$Label"
if ($LASTEXITCODE -ne 0) {
    throw "herdr plugin pane open failed (exit $LASTEXITCODE)"
}

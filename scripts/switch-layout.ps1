#Requires -Version 7
<#
.SYNOPSIS
  Link the GlazeWM config for one layout and reload GlazeWM if it is running.

.DESCRIPTION
  Creating the symlink needs an elevated shell or Windows Developer Mode, which setup-configs.ps1 turns on, so the
  Zebar layout button can run this without a UAC prompt.
#>
param(
    # Picks glazewm/config_<layout>.yaml. Laptop binds lwin (builtin keyboard), Kinesis and Desktop bind rwin,
    # and Desktop spreads workspaces over two monitors.
    [Parameter(Mandatory)]
    [ValidateSet('Laptop', 'Kinesis', 'Desktop')]
    [string]$Layout
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$PSScriptRoot\dotfile-link.ps1"

Link "$HOME\.glzr\glazewm\config.yaml" "$repo\glazewm\config_$($Layout.ToLower()).yaml" $backupRoot
# The Zebar layout button reads this to highlight the active layout, since it cannot see the symlink target.
Set-Content -LiteralPath "$repo\zebar\dev\current-layout.txt" -Value $Layout -NoNewline
if (Get-Process glazewm -ErrorAction Ignore) {
    glazewm command wm-reload-config
    if ($LASTEXITCODE -ne 0) { throw "glazewm wm-reload-config failed with exit code $LASTEXITCODE" }
}

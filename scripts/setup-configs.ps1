#Requires -Version 7
<#
.SYNOPSIS
  Link every config into your home and the GlazeWM config for one layout, then reload GlazeWM if it is running.

.DESCRIPTION
  Rerun it to switch layouts. Creating symlinks needs an elevated shell or Windows Developer Mode, which
  setup-packages.ps1 turns on. Anything already at a link target is moved to ~/.dotfiles-backup/<timestamp>/.
#>
param(
    # Picks glazewm/config_<layout>.yaml. Both bind lwin and rwin, and Dual spreads workspaces over two monitors.
    [Parameter(Mandatory)]
    [ValidateSet('Single', 'Dual')]
    [string]$Layout
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
# Backups go outside the linked directories: Claude Code scans its config dirs and would pick up a stale
# sibling copy.
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$repo\scripts\dotfile-link.ps1"

Write-Host ""
Write-Host "=== Linking dotfiles ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "PowerShell" -ForegroundColor Magenta
# MyDocuments follows OneDrive folder redirection, which $HOME\Documents does not.
Link "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" `
     "$repo\powershell\Microsoft.PowerShell_profile.ps1" $backupRoot

# Claude Code is not linked here. It runs only as the agent account, whose ~/.claude is linked by
# setup-claude.ps1.

Write-Host "VS Code" -ForegroundColor Magenta
Link "$env:APPDATA\Code\User\settings.json"    "$repo\vscode\settings.json"    $backupRoot
Link "$env:APPDATA\Code\User\keybindings.json" "$repo\vscode\keybindings.json" $backupRoot

# The per-repo presets file include()s the home one, so both must be linked.
Write-Host "CMake" -ForegroundColor Magenta
Link "$HOME\CMakeUserPreset.json" "$repo\cmake\CMakeUserPreset.json" $backupRoot
if (Test-Path "$HOME\dev\openziti\ziti-tunnel-sdk-c") {
    Link "$HOME\dev\openziti\ziti-tunnel-sdk-c\CMakeUserPresets.json" `
         "$repo\cmake\CMakeUserPresets.json" $backupRoot
} else {
    Write-Warning "ziti-tunnel-sdk-c not cloned, skipping its CMakeUserPresets.json link"
}

Write-Host "Visual Studio 2022" -ForegroundColor Magenta
Link "$HOME\_vsvimrc" "$repo\visualstudio\_vsvimrc" $backupRoot

Write-Host "WezTerm" -ForegroundColor Magenta
Link "$HOME\.wezterm.lua" "$repo\wezterm\.wezterm.lua" $backupRoot

Write-Host "intarsia" -ForegroundColor Magenta
Link "$HOME\.config\intarsia" "$repo\intarsia" $backupRoot

Write-Host "Windows Terminal" -ForegroundColor Magenta
Link "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
     "$repo\windows-terminal\settings.json" $backupRoot

Write-Host "Notepad++" -ForegroundColor Magenta
Link "$env:APPDATA\Notepad++\themes" "$repo\notepadpp\themes" $backupRoot

Write-Host "GlazeWM ($Layout)" -ForegroundColor Magenta
Link "$HOME\.glzr\glazewm\config.yaml" "$repo\glazewm\config_$($Layout.ToLower()).yaml" $backupRoot
if (Get-Process glazewm -ErrorAction Ignore) {
    glazewm command wm-reload-config
    if ($LASTEXITCODE -ne 0) { throw "glazewm wm-reload-config failed with exit code $LASTEXITCODE" }
}

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Cyan

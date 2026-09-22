#Requires -RunAsAdministrator
#Requires -Version 7

param(
    # Passed to switch-layout.ps1, which documents the layouts.
    [Parameter(Mandatory)]
    [ValidateSet('Laptop', 'Kinesis', 'Desktop')]
    [string]$Layout
)

$repo = Split-Path $PSScriptRoot -Parent
$ErrorActionPreference = 'Stop'
# Backups go outside the linked directories: Zebar and Claude Code scan their config dirs and would
# pick up a stale sibling copy.
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$repo\scripts\dotfile-link.ps1"

Write-Host ""
Write-Host "=== Linking dotfiles ===" -ForegroundColor Cyan
Write-Host ""

# ── PowerShell ──────────────────────────────────────────────
Write-Host "PowerShell" -ForegroundColor Magenta
Link "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" `
     "$repo\powershell\Microsoft.PowerShell_profile.ps1" $backupRoot

# Claude Code is not linked here. It runs only as the agent account, whose ~/.claude is linked by
# scripts/setup-agent-account.ps1.

# ── VS Code ─────────────────────────────────────────────────
Write-Host "VS Code" -ForegroundColor Magenta
Link "$env:APPDATA\Code\User\settings.json"    "$repo\vscode\settings.json"    $backupRoot
Link "$env:APPDATA\Code\User\keybindings.json" "$repo\vscode\keybindings.json" $backupRoot

# ── CMake ────────────────────────────────────────────────────
# The per-repo presets file include()s the home one, so both must be linked.
Write-Host "CMake" -ForegroundColor Magenta
Link "$HOME\CMakeUserPreset.json" "$repo\cmake\CMakeUserPreset.json" $backupRoot
if (Test-Path "$HOME\dev\openziti\ziti-tunnel-sdk-c") {
    Link "$HOME\dev\openziti\ziti-tunnel-sdk-c\CMakeUserPresets.json" `
         "$repo\cmake\CMakeUserPresets.json" $backupRoot
} else {
    Write-Warning "ziti-tunnel-sdk-c not cloned, skipping its CMakeUserPresets.json link"
}

# ── Visual Studio 2022 ──────────────────────────────────────
Write-Host "Visual Studio 2022" -ForegroundColor Magenta
Link "$HOME\_vsvimrc" "$repo\visualstudio\_vsvimrc" $backupRoot

# ── WezTerm ──────────────────────────────────────────────────
Write-Host "WezTerm" -ForegroundColor Magenta
Link "$HOME\.wezterm.lua" "$repo\wezterm\.wezterm.lua" $backupRoot

# ── GlazeWM ──────────────────────────────────────────────────
Write-Host "GlazeWM" -ForegroundColor Magenta
& "$PSScriptRoot\switch-layout.ps1" -Layout $Layout
# Lets a non-elevated shell create symlinks, so the Zebar layout button runs switch-layout.ps1 without UAC.
$devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
New-Item -Path $devModeKey -Force | Out-Null
Set-ItemProperty -Path $devModeKey -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
# Windows handles Win+L before any keyboard hook, so the win+l focus binding never reaches GlazeWM.
# This also removes Lock from ctrl+alt+del. Takes effect at next sign-in.
$lockPolicy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
New-Item -Path $lockPolicy -Force | Out-Null
Set-ItemProperty -Path $lockPolicy -Name DisableLockWorkstation -Value 1 -Type DWord

# ── Zebar ────────────────────────────────────────────────────
# Assets (icons + scripts) are junctioned
# Config files are symlinked individually.
Write-Host "Zebar" -ForegroundColor Magenta
Link "$HOME\.glzr\zebar\normalize.css"   "$repo\zebar\normalize.css" $backupRoot
Link "$HOME\.glzr\zebar\settings.json"   "$repo\zebar\settings.json" $backupRoot
Link "$HOME\.glzr\zebar\dev"             "$repo\zebar\dev"           $backupRoot

# ── Windows Terminal ─────────────────────────────────────────
Write-Host "Windows Terminal" -ForegroundColor Magenta
Link "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
     "$repo\windows-terminal\settings.json" $backupRoot

# ── Notepad++ ────────────────────────────────────────────────
Write-Host "Notepad++" -ForegroundColor Magenta
Link "$env:APPDATA\Notepad++\themes" "$repo\notepadpp\themes" $backupRoot

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Cyan
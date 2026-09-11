#Requires -RunAsAdministrator
#Requires -Version 7

$repo = $PSScriptRoot
$ErrorActionPreference = 'Stop'
# Backups go outside the linked directories: Zebar and Claude Code scan their config dirs and would
# pick up a stale sibling copy.
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$repo\scripts\dotfile-link.ps1"

function StartupShortcut([string]$name, [string]$exe, [string]$arguments, [string]$workingDir) {
    if (!(Test-Path $exe)) {
        Write-Warning "Executable missing, skipping shortcut: $exe"
        return
    }

    $target = Join-Path ([Environment]::GetFolderPath('Startup')) "$name.lnk"
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($target)
    $shortcut.TargetPath = $exe
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $workingDir
    $shortcut.Save()

    Write-Host "  Startup: $target" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Linking dotfiles ===" -ForegroundColor Cyan
Write-Host ""

# ── PowerShell ──────────────────────────────────────────────
Write-Host "PowerShell" -ForegroundColor Magenta
Link "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" `
     "$repo\powershell\Microsoft.PowerShell_profile.ps1" $backupRoot

# ── Claude Code ─────────────────────────────────────────────
Write-Host "Claude Code" -ForegroundColor Magenta
Link "$HOME\.claude\CLAUDE.md"          "$repo\claude\context.md"       $backupRoot
Link "$HOME\.claude\settings.json"      "$repo\claude\settings.json"    $backupRoot
Link "$HOME\.claude\agents"             "$repo\claude\agents"           $backupRoot
Link "$HOME\.claude\output-styles"      "$repo\claude\output-styles"    $backupRoot
foreach ($skill in Get-ChildItem "$repo\claude\skills" -Directory) {
    Link "$HOME\.claude\skills\$($skill.Name)" $skill.FullName $backupRoot
}

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
Link "$HOME\.glzr\glazewm\config.yaml" "$repo\glazewm\config.yaml" $backupRoot
# Runs the repo copy directly. GlazeWM's shutdown_commands kills AutoHotkey64.
StartupShortcut "winkey-fix" "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" `
                "`"$repo\glazewm\winkey-fix.ahk`"" "$repo\glazewm"

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
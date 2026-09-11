#Requires -RunAsAdministrator
# Windows PowerShell 5.1 cannot remove a junction without -Recurse, and with it deletes the repo files the
# junction points at (PowerShell/PowerShell#621).
#Requires -Version 7

$repo = $PSScriptRoot
$ErrorActionPreference = 'Stop'
# Backups go outside the linked directories: Zebar and Claude Code scan their config dirs and would
# pick up a stale sibling copy.
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

function Link([string]$target, [string]$source) {
    if (!(Test-Path $source)) {
        Write-Warning "Source missing, skipping: $source"
        return
    }

    $dir = Split-Path $target
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.LinkType) {
            Remove-Item $target -Force
        } else {
            # Mirror the full target path: several targets share the leaf settings.json.
            $backup = Join-Path $backupRoot ($target -replace '^([A-Za-z]):', '$1')
            New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
            Move-Item $target $backup
            Write-Warning "Existing item moved to: $backup"
        }
    }

    $isDir = (Get-Item $source) -is [System.IO.DirectoryInfo]
    if ($isDir) {
        New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
    }

    Write-Host "  Linked: $target" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Linking dotfiles ===" -ForegroundColor Cyan
Write-Host ""

# ── PowerShell ──────────────────────────────────────────────
Write-Host "PowerShell" -ForegroundColor Magenta
Link "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" `
     "$repo\powershell\Microsoft.PowerShell_profile.ps1"

# ── Claude Code ─────────────────────────────────────────────
Write-Host "Claude Code" -ForegroundColor Magenta
Link "$HOME\.claude\CLAUDE.md"          "$repo\claude\context.md"
Link "$HOME\.claude\settings.json"      "$repo\claude\settings.json"
Link "$HOME\.claude\agents"             "$repo\claude\agents"
Link "$HOME\.claude\output-styles"      "$repo\claude\output-styles"
foreach ($skill in Get-ChildItem "$repo\claude\skills" -Directory) {
    Link "$HOME\.claude\skills\$($skill.Name)" $skill.FullName
}

# ── VS Code ─────────────────────────────────────────────────
Write-Host "VS Code" -ForegroundColor Magenta
Link "$env:APPDATA\Code\User\settings.json"    "$repo\vscode\settings.json"
Link "$env:APPDATA\Code\User\keybindings.json" "$repo\vscode\keybindings.json"

# ── CMake ────────────────────────────────────────────────────
# The per-repo presets file include()s the home one, so both must be linked.
Write-Host "CMake" -ForegroundColor Magenta
Link "$HOME\CMakeUserPreset.json" "$repo\cmake\CMakeUserPreset.json"
if (Test-Path "$HOME\dev\openziti\ziti-tunnel-sdk-c") {
    Link "$HOME\dev\openziti\ziti-tunnel-sdk-c\CMakeUserPresets.json" `
         "$repo\cmake\CMakeUserPresets.json"
} else {
    Write-Warning "ziti-tunnel-sdk-c not cloned, skipping its CMakeUserPresets.json link"
}

# ── Visual Studio 2022 ──────────────────────────────────────
Write-Host "Visual Studio 2022" -ForegroundColor Magenta
Link "$HOME\_vsvimrc" "$repo\visualstudio\_vsvimrc"

# ── WezTerm ──────────────────────────────────────────────────
Write-Host "WezTerm" -ForegroundColor Magenta
Link "$HOME\.wezterm.lua" "$repo\wezterm\.wezterm.lua"

# ── GlazeWM ──────────────────────────────────────────────────
Write-Host "GlazeWM" -ForegroundColor Magenta
Link "$HOME\.glzr\glazewm\config.yaml" "$repo\glazewm\config.yaml"

# ── Zebar ────────────────────────────────────────────────────
# Assets (icons + scripts) are junctioned
# Config files are symlinked individually.
Write-Host "Zebar" -ForegroundColor Magenta
Link "$HOME\.glzr\zebar\normalize.css"   "$repo\zebar\normalize.css"
Link "$HOME\.glzr\zebar\settings.json"   "$repo\zebar\settings.json"
Link "$HOME\.glzr\zebar\dev"             "$repo\zebar\dev"

# ── Windows Terminal ─────────────────────────────────────────
Write-Host "Windows Terminal" -ForegroundColor Magenta
Link "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
     "$repo\windows-terminal\settings.json"

# ── Notepad++ ────────────────────────────────────────────────
Write-Host "Notepad++" -ForegroundColor Magenta
Link "$env:APPDATA\Notepad++\themes" "$repo\notepadpp\themes"

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Cyan
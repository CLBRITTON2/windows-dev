#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Set up a fresh Windows machine: clone this repo, then run setup-packages.ps1, setup-configs.ps1, and
  setup-claude.ps1 in that order.

.DESCRIPTION
  Runs under Windows PowerShell 5.1 because a fresh machine has no pwsh 7 yet. setup-packages.ps1 installs it,
  and the other two run under it. Safe to rerun: the clone is skipped when the repo exists.
#>
param(
    # Passed to setup-configs.ps1, which documents the layouts.
    [Parameter(Mandatory)]
    [ValidateSet('Single', 'Dual')]
    [string]$Layout
)

$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/CLBRITTON2/windows-dev'
$repo = "$HOME\dev\windows-dev"
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
# Called by full path: this session's PATH predates the git install.
$git = "$env:ProgramFiles\Git\cmd\git.exe"

if (-not (Test-Path $git)) {
    Write-Host "Installing git" -ForegroundColor Cyan
    winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget install Git.Git failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path $repo)) {
    Write-Host "Cloning $repoUrl" -ForegroundColor Cyan
    & $git clone $repoUrl $repo
    if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }
}

& "$repo\scripts\setup-packages.ps1"

& $pwsh -NoProfile -File "$repo\scripts\setup-configs.ps1" -Layout $Layout
if ($LASTEXITCODE -ne 0) { throw "setup-configs.ps1 failed with exit code $LASTEXITCODE" }

& $pwsh -NoProfile -File "$repo\scripts\setup-claude.ps1"
if ($LASTEXITCODE -ne 0) { throw "setup-claude.ps1 failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Left to do by hand, see README.md: Ziti Desktop Edge, thide, VsVim, /login, gh auth login." -ForegroundColor Yellow

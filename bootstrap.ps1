#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Set up a fresh Windows machine: git, this repo, every app in winget/packages.json, configs, and the agent
  account.

.DESCRIPTION
  Runs under Windows PowerShell 5.1 because a fresh machine has no pwsh 7 yet, then hands off to pwsh 7 for
  the setup scripts. Safe to rerun: the clone is skipped when the repo exists and installed apps are not
  upgraded.
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Laptop', 'Kinesis', 'Desktop')]
    [string]$Layout
)

$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/CLBRITTON2/windows-dev'
$repo = "$HOME\dev\windows-dev"
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"

function Assert-ExitCode([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed with exit code $LASTEXITCODE" }
}

function Update-SessionPath {
    # winget installs update the registry PATH but not this session's copy.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Get-Command git -ErrorAction Ignore)) {
    Write-Host "Installing git" -ForegroundColor Cyan
    winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
    Assert-ExitCode 'winget install Git.Git'
    Update-SessionPath
}

if (-not (Test-Path $repo)) {
    Write-Host "Cloning $repoUrl" -ForegroundColor Cyan
    git clone $repoUrl $repo
    Assert-ExitCode 'git clone'
}

Write-Host "Installing apps" -ForegroundColor Cyan
# --no-upgrade: upgrading an installed app can fail for reasons unrelated to setup (MSYS2 refuses winget upgrades).
winget import -i "$repo\winget\packages.json" --no-upgrade --accept-package-agreements --accept-source-agreements
Assert-ExitCode 'winget import'
Update-SessionPath

& $pwsh -NoProfile -File "$repo\setup-configs.ps1" -Layout $Layout
Assert-ExitCode 'setup-configs.ps1'

& $pwsh -NoProfile -File "$repo\scripts\setup-agent-account.ps1"
Assert-ExitCode 'setup-agent-account.ps1'

Write-Host ""
Write-Host "Left to do by hand, see README.md: Ziti Desktop Edge, thide, /login, gh auth login." -ForegroundColor Yellow

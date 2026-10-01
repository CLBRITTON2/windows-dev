#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install every app in winget/packages.json plus PSFzf, vcpkg, and the VS Code extensions, and set the machine
  settings the configs rely on.

.DESCRIPTION
  Runs under Windows PowerShell 5.1 because a fresh machine has no pwsh 7 yet. Safe to rerun: installed apps are
  not upgraded.
#>
param()

$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
$vcpkgRoot = 'C:\vcpkg'
$vscodeExtensions = @(
    'anthropic.claude-code'
    'golang.go'
    'ms-vscode.cmake-tools'
    'ms-vscode.cpp-devtools'
    'ms-vscode.cpptools'
    'ms-vscode.cpptools-extension-pack'
    'ms-vscode.cpptools-themes'
    'mvllow.rose-pine'
    'vscodevim.vim'
)

function Assert-ExitCode([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed with exit code $LASTEXITCODE" }
}

function Update-SessionPath {
    # winget installs update the registry PATH but not this session's copy.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

# The agent account cannot execute the Store pwsh under WindowsApps, and a present Store build satisfies the import
# below, so swap it for the MSI build first.
if (Get-AppxPackage Microsoft.PowerShell) {
    Write-Host "Removing Store pwsh" -ForegroundColor Cyan
    Get-AppxPackage Microsoft.PowerShell | Remove-AppxPackage
}
if (-not (Test-Path $pwsh)) {
    Write-Host "Installing pwsh (MSI)" -ForegroundColor Cyan
    winget install --id Microsoft.PowerShell --exact --source winget --installer-type wix --accept-package-agreements --accept-source-agreements
    Assert-ExitCode 'winget install Microsoft.PowerShell'
}

Write-Host "Installing apps" -ForegroundColor Cyan
# --no-upgrade: upgrading an installed app can fail for reasons unrelated to setup (MSYS2 refuses winget upgrades).
winget import -i "$repo\winget\packages.json" --no-upgrade --accept-package-agreements --accept-source-agreements
Assert-ExitCode 'winget import'
Update-SessionPath

Write-Host "Installing PSFzf" -ForegroundColor Cyan
# The profile imports it. PSResourceGet ships with pwsh 7.4+, and installing from pwsh puts it in the pwsh module path.
& $pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable PSFzf)) { Install-PSResource PSFzf -TrustRepository -ErrorAction Stop }"
Assert-ExitCode 'Install-PSResource PSFzf'

# The CMake presets expect vcpkg at this path. It is a git checkout, not a winget package.
if (-not (Test-Path $vcpkgRoot)) {
    Write-Host "Installing vcpkg" -ForegroundColor Cyan
    git clone https://github.com/microsoft/vcpkg $vcpkgRoot
    Assert-ExitCode 'git clone vcpkg'
    & "$vcpkgRoot\bootstrap-vcpkg.bat" -disableMetrics
    Assert-ExitCode 'bootstrap-vcpkg.bat'
}

Write-Host "Installing VS Code extensions" -ForegroundColor Cyan
foreach ($extension in $vscodeExtensions) {
    code --install-extension $extension
    Assert-ExitCode "code --install-extension $extension"
}

Write-Host "Machine settings" -ForegroundColor Cyan
# Lets a non-elevated shell create symlinks, so setup-configs.ps1 runs without UAC.
$devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
New-Item -Path $devModeKey -Force | Out-Null
Set-ItemProperty -Path $devModeKey -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
# Windows handles Win+L before any keyboard hook, so the win+l focus binding never reaches GlazeWM.
# This also removes Lock from ctrl+alt+del. Takes effect at next sign-in.
$lockPolicy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
New-Item -Path $lockPolicy -Force | Out-Null
Set-ItemProperty -Path $lockPolicy -Name DisableLockWorkstation -Value 1 -Type DWord

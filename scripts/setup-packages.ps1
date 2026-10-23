#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install every app in winget/packages.json plus PSFzf, vcpkg, the MSYS2 compilers, the VS Code extensions, and the
  latest carronade, rallypoint, and intarsia releases, and set the machine settings the configs rely on.

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
# The profile puts mingw64 first on PATH, and cmake/CMakeUserPreset.json builds with its gcc, ninja, pkg-config, and
# OpenSSL.
$msysPackages = @(
    'mingw-w64-x86_64-gcc'
    'mingw-w64-x86_64-gdb'
    'mingw-w64-x86_64-ninja'
    'mingw-w64-x86_64-pkgconf'
    'mingw-w64-x86_64-openssl'
)
# GlazeWM starts each exe from its Dir.
$releaseTools = @(
    [pscustomobject]@{ Repo = 'carronade'; Exes = @('carronade.exe'); Dir = "$HOME\.cargo\bin" }
    [pscustomobject]@{ Repo = 'rallypoint'; Exes = @('rallypoint.exe'); Dir = "$HOME\.cargo\bin" }
    [pscustomobject]@{
        Repo = 'intarsia'; Exes = @('intarsia.exe', 'intarsia-cli.exe'); Dir = "$env:LOCALAPPDATA\Programs\intarsia"
    }
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

Write-Host "Installing MSYS2 packages" -ForegroundColor Cyan
# A login shell, so the first run initializes the pacman keyring.
& 'C:\msys64\usr\bin\bash.exe' -lc "pacman -S --needed --noconfirm $($msysPackages -join ' ')"
Assert-ExitCode 'pacman -S'

Write-Host "Installing carronade, rallypoint, and intarsia releases" -ForegroundColor Cyan
foreach ($tool in $releaseTools) {
    if (Test-Path "$($tool.Dir)\$($tool.Exes[0])") { continue }
    $release = Invoke-RestMethod "https://api.github.com/repos/CLBRITTON2/$($tool.Repo)/releases/latest"
    $zip = Join-Path $env:TEMP "$($tool.Repo).zip"
    $unpacked = Join-Path $env:TEMP $tool.Repo
    Invoke-WebRequest $release.assets[0].browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip $unpacked -Force
    New-Item -ItemType Directory -Force $tool.Dir | Out-Null
    foreach ($exe in $tool.Exes) {
        $found = @(Get-ChildItem $unpacked -Recurse -Filter $exe)
        if ($found.Count -ne 1) { throw "$($release.assets[0].name) has $($found.Count) copies of $exe, expected 1" }
        Copy-Item $found[0].FullName $tool.Dir
    }
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
# glazewm/winkey-fix.ahk sets DisableLockWorkstation while a Win key is held, so Win+L reaches GlazeWM's focus
# binding, and the Policies key is otherwise read-only to a non-elevated process. CreateSubKey because AutoHotkey's
# RegWrite opens the key with KEY_WRITE.
$lockPolicy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
New-Item -Path $lockPolicy -Force | Out-Null
$lockPolicyAcl = Get-Acl $lockPolicy
$lockPolicyAcl.AddAccessRule([Security.AccessControl.RegistryAccessRule]::new(
        "$env:USERDOMAIN\$env:USERNAME", 'SetValue, CreateSubKey', 'Allow'))
Set-Acl $lockPolicy $lockPolicyAcl

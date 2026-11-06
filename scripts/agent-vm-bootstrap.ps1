#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install the laptop's dev toolchain, PSFzf, vcpkg and the MSYS2 compilers in the agent VM. Runs inside the VM as
  claude, over ssh.

.DESCRIPTION
  Written for Windows PowerShell 5.1, since pwsh is one of the packages it installs. Rerunning it is safe: it skips
  packages that are already installed and does not upgrade them. Claude Code and herdr come from their own
  installers in agent-bootstrap.ps1, since the winget Claude Code never updates itself and shadows the native one
  on PATH.

  The evaluation ISO ships winget 1.6, which cannot read the current package index, and an ssh logon never gets the
  winget source package, so it installs the latest winget and the source package first.

  From the host, in this repo:
    scp scripts\agent-vm-bootstrap.ps1 claude-vm:
    ssh claude-vm powershell -NoProfile -ExecutionPolicy RemoteSigned -File agent-vm-bootstrap.ps1
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
$downloadDir = Join-Path $env:TEMP 'agent-vm-bootstrap'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$release = Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest
$latestVersion = [version]$release.tag_name.TrimStart('v')
if (Test-Path -LiteralPath $winget) {
    $installedVersion = [version](& $winget --version).TrimStart('v')
} else {
    $installedVersion = [version]'0.0'
}
if ($installedVersion -lt $latestVersion) {
    Write-Host "==> updating winget $installedVersion to $latestVersion"
    $bundleName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $dependenciesName = 'DesktopAppInstaller_Dependencies.zip'
    foreach ($assetName in $bundleName, $dependenciesName) {
        $asset = $release.assets | Where-Object name -eq $assetName
        if (-not $asset) { throw "winget-cli $($release.tag_name) has no release asset $assetName" }
        Invoke-WebRequest $asset.browser_download_url -OutFile (Join-Path $downloadDir $assetName) -UseBasicParsing
    }
    $dependenciesDir = Join-Path $downloadDir 'dependencies'
    Expand-Archive (Join-Path $downloadDir $dependenciesName) $dependenciesDir -Force
    $dependencyPaths = @(Get-ChildItem (Join-Path $dependenciesDir 'x64') -Filter *.appx | ForEach-Object FullName)
    Add-AppxPackage -Path (Join-Path $downloadDir $bundleName) -DependencyPath $dependencyPaths -ForceApplicationShutdown
}

# Without it every install fails with 0x8a15000f "Data required by the source is missing".
Write-Host '==> installing the winget source package'
$sourcePackage = Join-Path $downloadDir 'source2.msix'
Invoke-WebRequest https://cdn.winget.microsoft.com/cache/source2.msix -OutFile $sourcePackage -UseBasicParsing
Add-AppxPackage -Path $sourcePackage

function Install-WingetPackage([string] $packageId, [string[]] $extraArguments) {
    Write-Host "==> $packageId"
    $wingetOutput = & $winget install --id $packageId --exact --source winget --silent --no-upgrade `
        --accept-source-agreements --accept-package-agreements --disable-interactivity @extraArguments
    # 0x8A150061 is "A package version is already installed", what --no-upgrade returns on a rerun.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335135) {
        throw "winget install $packageId failed (exit $LASTEXITCODE): $(($wingetOutput | Select-Object -Last 5) -join ' ')"
    }
}

# The toolchain of winget/packages.json that the profile and the repos' builds use, without the desktop apps.
foreach ($packageId in @(
    'Git.Git'
    'GitHub.cli'
    'BurntSushi.ripgrep.MSVC'
    'Rustlang.Rustup'
    'Microsoft.VisualStudio.2022.Community'
    'Kitware.CMake'
    'GoLang.Go'
    'OpenJS.NodeJS.LTS'
    'Microsoft.Coreutils'
    'eza-community.eza'
    'junegunn.fzf'
    'MSYS2.MSYS2'
)) {
    Install-WingetPackage $packageId @()
}
# The default msix installer fails over ssh with -2147009255.
Install-WingetPackage Microsoft.PowerShell @('--installer-type', 'wix', '--scope', 'machine')

# winget installs Visual Studio without MSBuild, which the profile's vswhere line needs. These are the laptop's workloads.
$vsInstallerDir = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"
$vsInstallPath = & "$vsInstallerDir\vswhere.exe" -latest -property installationPath
$vsSetup = Start-Process "$vsInstallerDir\setup.exe" -Wait -PassThru -ArgumentList 'modify', '--installPath',
    "`"$vsInstallPath`"", '--add', 'Microsoft.VisualStudio.Workload.NativeDesktop', '--add',
    'Microsoft.VisualStudio.Workload.ManagedDesktop', '--includeRecommended', '--quiet', '--norestart'
# 3010 is "succeeded, reboot required".
if ($vsSetup.ExitCode -ne 0 -and $vsSetup.ExitCode -ne 3010) {
    throw "Visual Studio setup.exe modify failed (exit $($vsSetup.ExitCode))"
}

# winget installs update the registry PATH but not this session's copy.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host '==> PSFzf'
& "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -Command `
    'if (-not (Get-Module -ListAvailable PSFzf)) { Install-PSResource PSFzf -TrustRepository -ErrorAction Stop }'
if ($LASTEXITCODE -ne 0) { throw "Install-PSResource PSFzf failed (exit $LASTEXITCODE)" }

# The CMake presets expect vcpkg at this path.
$vcpkgRoot = 'C:\vcpkg'
if (-not (Test-Path -LiteralPath $vcpkgRoot)) {
    Write-Host '==> vcpkg'
    git clone --quiet https://github.com/microsoft/vcpkg $vcpkgRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone vcpkg failed (exit $LASTEXITCODE)" }
    & "$vcpkgRoot\bootstrap-vcpkg.bat" -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw "bootstrap-vcpkg.bat failed (exit $LASTEXITCODE)" }
}

Write-Host '==> MSYS2 packages'
# A login shell, so the first run initializes the pacman keyring.
& 'C:\msys64\usr\bin\bash.exe' -lc ('pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb ' +
    'mingw-w64-x86_64-ninja mingw-w64-x86_64-pkgconf mingw-w64-x86_64-openssl')
if ($LASTEXITCODE -ne 0) { throw "pacman -S failed (exit $LASTEXITCODE)" }

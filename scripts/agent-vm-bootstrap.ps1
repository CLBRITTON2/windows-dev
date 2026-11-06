#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install git, gh and pwsh in the agent VM, log gh in, clone the repositories, install Claude Code and herdr, then
  dot-source the personal setup script if one is given. Runs inside the VM as claude, over ssh, started by
  new-agent-vm.ps1.

.DESCRIPTION
  Written for Windows PowerShell 5.1, since pwsh is one of the packages it installs. Rerunning it is safe: it skips
  packages that are already installed and does not upgrade them. Claude Code and herdr come from their own
  installers, since the winget Claude Code never updates itself and shadows the native one on PATH.

  -PersonalSetupPath names a script beside this one with a personal toolchain and dotfiles, such as
  agent-vm-personal-setup.ps1. It runs last, in this script's scope, so it can use $setup, $winget, $herdr and
  Install-WingetPackage.

  The evaluation ISO ships winget 1.6, which cannot read the current package index, and an ssh logon never gets the
  winget source package, so it installs the latest winget and the source package first.

  -SetupPath is the JSON new-agent-vm.ps1 writes: the dev root, git identity, and each repository's path
  under the dev root and https URL. A repository already cloned is left alone. The first line of stdin is the
  read-only token gh logs in with.
#>
param(
    [Parameter(Mandatory)] [string] $SetupPath,
    [string] $PersonalSetupPath
)
$ErrorActionPreference = 'Stop'
$gitHubToken = [Console]::In.ReadLine()
if (-not $gitHubToken) { throw 'stdin held no GitHub token' }
$setup = Get-Content -LiteralPath $SetupPath -Raw -Encoding UTF8 | ConvertFrom-Json
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

Install-WingetPackage Git.Git @()
Install-WingetPackage GitHub.cli @()
# The default msix installer fails over ssh with -2147009255.
Install-WingetPackage Microsoft.PowerShell @('--installer-type', 'wix', '--scope', 'machine')
# new-agent-vm.ps1 sets Windows PowerShell as the login shell, since pwsh is not installed until here. This session
# keeps it, and every later ssh logon gets pwsh.
New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Force `
    -Value "$env:ProgramFiles\PowerShell\7\pwsh.exe" | Out-Null

# winget installs update the registry PATH but not this session's copy.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path', 'User')

# Claude Code turns fullscreen off over ssh, and herdr panes inherit SSH_CONNECTION from the logon that started the
# herdr server. Set here too, so any herdr server this script starts has it.
[Environment]::SetEnvironmentVariable('CLAUDE_CODE_NO_FLICKER', '1', 'User')
$env:CLAUDE_CODE_NO_FLICKER = '1'

Write-Host '==> gh auth login'
$gitHubToken | & gh auth login --hostname github.com --git-protocol https --with-token
if ($LASTEXITCODE -ne 0) { throw "gh auth login failed (exit $LASTEXITCODE)" }
& gh auth setup-git
if ($LASTEXITCODE -ne 0) { throw "gh auth setup-git failed (exit $LASTEXITCODE)" }

git config --global user.name $setup.gitUserName
if ($LASTEXITCODE -ne 0) { throw "git config user.name failed (exit $LASTEXITCODE)" }
git config --global user.email $setup.gitUserEmail
if ($LASTEXITCODE -ne 0) { throw "git config user.email failed (exit $LASTEXITCODE)" }

# The same paths as on the laptop, so perusal maps each repository to its copy here.
foreach ($repo in $setup.repos) {
    $workTree = Join-Path $setup.devRoot $repo.path
    if (Test-Path -LiteralPath $workTree) { continue }
    Write-Host "==> clone $($repo.path)"
    git clone --quiet $repo.url $workTree
    if ($LASTEXITCODE -ne 0) { throw "git clone $($repo.url) failed (exit $LASTEXITCODE)" }
}

# The ~/dev paths in settings.json and the agents context resolve the same as on the laptop.
if (-not (Test-Path -LiteralPath "$HOME\dev")) {
    Write-Host "==> junction $HOME\dev to $($setup.devRoot)"
    New-Item -ItemType Junction -Path "$HOME\dev" -Target $setup.devRoot | Out-Null
}

# The Claude Code installer sets PATH only for the session it runs in.
$binDir = "$HOME\.local\bin"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
}
$env:Path += ";$binDir"

# Both installers turn on Set-StrictMode, so each runs in a child scope to keep it out of this script.
if (-not (Test-Path -LiteralPath "$binDir\claude.exe")) {
    Write-Host '==> Claude Code'
    & ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1)))
}
# The installer's stable alias. The release folder it puts on PATH changes with every herdr version.
$herdr = "$env:LOCALAPPDATA\Programs\Herdr\bin\herdr.exe"
if (-not (Test-Path -LiteralPath $herdr)) {
    Write-Host '==> herdr'
    & ([scriptblock]::Create((Invoke-RestMethod https://herdr.dev/install.ps1)))
}

if ($PersonalSetupPath) {
    Write-Host "==> $PersonalSetupPath"
    . (Join-Path $PSScriptRoot $PersonalSetupPath)
}

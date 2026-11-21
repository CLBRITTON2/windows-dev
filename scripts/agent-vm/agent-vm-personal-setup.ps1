<#
.SYNOPSIS
  The personal part of the agent VM setup: the laptop's dev toolchain, gopls, perusal, zen, csharp-ls, Visual Studio workloads, what the desktop-edge-win UI
  tests need, terminus and its MCP registration, PSFzf, vcpkg and the MSYS2 compilers, herdr's config and its focus-file, diff-popup, zen and claude-tab plugins, and the agent's dotfile links.

.DESCRIPTION
  agent-vm-bootstrap.ps1 dot-sources it last, so it runs under Windows PowerShell 5.1 in the bootstrap's scope, with
  $devRoot, $winget, $pwsh, Write-Step and Install-WingetPackage from there, and the repositories, Claude Code and herdr already in place.
  Rerunning it is safe, like the bootstrap.
#>

# The toolchain of winget/packages.json that the profile and the repos' builds use, without the desktop apps.
foreach ($packageId in @(
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
    'Microsoft.NuGet'
    'ast-grep.ast-grep'
    'jqlang.jq'
)) {
    Install-WingetPackage $packageId @()
}

# winget installs Visual Studio without MSBuild, which the profile's vswhere line needs. These are the laptop's workloads.
Write-Step 'Visual Studio workloads (prints nothing until done)'
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

# Claude Code's Go LSP runs gopls from PATH. The Go installer puts %USERPROFILE%\go\bin there.
Write-Step 'gopls'
& go install golang.org/x/tools/gopls@latest
if ($LASTEXITCODE -ne 0) { throw "go install gopls failed (exit $LASTEXITCODE)" }

# The diff-popup herdr plugin runs perusal show.
Write-Step 'perusal'
& go install github.com/CLBRITTON2/perusal/cmd/perusal@latest
if ($LASTEXITCODE -ne 0) { throw "go install perusal failed (exit $LASTEXITCODE)" }

# The zen herdr plugin runs zen.exe.
Write-Step 'zen'
& go install github.com/CLBRITTON2/herdr-zen/cmd/zen@latest
if ($LASTEXITCODE -ne 0) { throw "go install zen failed (exit $LASTEXITCODE)" }

# The fork's go.mod still declares github.com/michaelquigley/terminus, so go install of the fork's path fails. Build
# the fork's claude-reviewer-schema commit (Claude Code rejects upstream's 2020-12 findings schema) from an archive.
Write-Step 'terminus'
$terminusCommit = '86a3f47'
$terminusSource = Join-Path $env:TEMP "terminus-$terminusCommit"
$terminusZip = "$terminusSource.zip"
git -C (Join-Path $devRoot 'CLBRITTON2\terminus') archive --format=zip -o $terminusZip $terminusCommit
if ($LASTEXITCODE -ne 0) { throw "git archive of terminus $terminusCommit failed (exit $LASTEXITCODE)" }
Expand-Archive -LiteralPath $terminusZip -DestinationPath $terminusSource -Force
& go -C $terminusSource install ./cmd/terminus
if ($LASTEXITCODE -ne 0) { throw "go install terminus $terminusCommit failed (exit $LASTEXITCODE)" }
& claude mcp get terminus *> $null
if ($LASTEXITCODE -ne 0) {
    & claude mcp add --scope user terminus -- "$HOME\go\bin\terminus.exe" serve
    if ($LASTEXITCODE -ne 0) { throw "claude mcp add terminus failed (exit $LASTEXITCODE)" }
}

# The csharp-lsp plugin runs csharp-ls from ~\.dotnet\tools. 0.21.0 and later target net10.0, which the .NET 9 SDK
# cannot install.
Write-Step 'csharp-ls'
& dotnet tool update --global csharp-ls --version 0.20.0
if ($LASTEXITCODE -ne 0) { throw "dotnet tool update csharp-ls failed (exit $LASTEXITCODE)" }

Write-Step 'desktop-edge-win UI test prerequisites'
# The NuGet.Config Visual Studio leaves lists only its offline packages, so nuget restore cannot find the rest.
$nugetSources = & nuget sources list -Format Short
if ($LASTEXITCODE -ne 0) { throw "nuget sources list failed (exit $LASTEXITCODE)" }
if (-not ($nugetSources -match 'https://api\.nuget\.org/v3/index\.json')) {
    & nuget sources add -Name nuget.org -Source https://api.nuget.org/v3/index.json
    if ($LASTEXITCODE -ne 0) { throw "nuget sources add nuget.org failed (exit $LASTEXITCODE)" }
}
# WinAppDriver refuses to start without Developer Mode.
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock -Force `
    -Name AllowDevelopmentWithoutDevLicense -PropertyType DWord -Value 1 | Out-Null
# A firewall prompt for a new listener, such as ziti-edge-tunnel's, covers the window the tests click.
Set-NetFirewallProfile -All -NotifyOnListen False
# UITests exists only on the try-appium branch.
$uiTestsInstall = Join-Path $env:TEMP 'desktop-edge-win-ci-install.ps1'
$uiTestsInstallScript = git -C (Join-Path $devRoot 'openziti\desktop-edge-win') show origin/try-appium:UITests/ci-install.ps1
if ($LASTEXITCODE -ne 0) { throw "git show of desktop-edge-win's ci-install.ps1 failed (exit $LASTEXITCODE)" }
Set-Content -LiteralPath $uiTestsInstall -Value $uiTestsInstallScript
& $pwsh -NoProfile -File $uiTestsInstall
if ($LASTEXITCODE -ne 0) { throw "desktop-edge-win ci-install.ps1 failed (exit $LASTEXITCODE)" }

Write-Step 'PSFzf'
& $pwsh -NoProfile -Command `
    'if (-not (Get-Module -ListAvailable PSFzf)) { Install-PSResource PSFzf -Repository PSGallery -TrustRepository -ErrorAction Stop }'
if ($LASTEXITCODE -ne 0) { throw "Install-PSResource PSFzf failed (exit $LASTEXITCODE)" }

# The CMake presets expect vcpkg at this path.
$vcpkgRoot = 'C:\vcpkg'
if (-not (Test-Path -LiteralPath $vcpkgRoot)) {
    Write-Step 'vcpkg'
    git clone --quiet https://github.com/microsoft/vcpkg $vcpkgRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone vcpkg failed (exit $LASTEXITCODE)" }
    & "$vcpkgRoot\bootstrap-vcpkg.bat" -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw "bootstrap-vcpkg.bat failed (exit $LASTEXITCODE)" }
}

Write-Step 'MSYS2 packages'
# A login shell, so the first run initializes the pacman keyring.
& 'C:\msys64\usr\bin\bash.exe' -lc ('pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb ' +
    'mingw-w64-x86_64-ninja mingw-w64-x86_64-pkgconf mingw-w64-x86_64-openssl')
if ($LASTEXITCODE -ne 0) { throw "pacman -S failed (exit $LASTEXITCODE)" }

$windowsDev = Join-Path $devRoot 'windows-dev'
$herdrConfig = Join-Path $env:APPDATA 'herdr\config.toml'
if (-not (Test-Path -LiteralPath $herdrConfig)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $herdrConfig) | Out-Null
    Copy-Item -LiteralPath (Join-Path $windowsDev 'herdr\config.toml') -Destination $herdrConfig
}

$plugins = & $herdr plugin list --json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "herdr plugin list failed (exit $LASTEXITCODE)" }
foreach ($pluginDir in @('focus-file', 'diff-popup', 'zen', 'claude-tab')) {
    $pluginId = "windows-dev.$pluginDir"
    if ($plugins.result.plugins.plugin_id -notcontains $pluginId) {
        & $herdr plugin link (Join-Path $windowsDev "herdr\$pluginDir")
        if ($LASTEXITCODE -ne 0) { throw "herdr plugin link $pluginId failed (exit $LASTEXITCODE)" }
    }
}

# The CLAUDE.md links are untracked in every repo, so git status would list them in each one.
$gitIgnore = "$HOME\.config\git\ignore"
if (-not (Test-Path -LiteralPath $gitIgnore) -or (Get-Content -LiteralPath $gitIgnore) -notcontains 'CLAUDE.md') {
    New-Item -ItemType Directory -Force -Path (Split-Path $gitIgnore) | Out-Null
    Add-Content -LiteralPath $gitIgnore -Value 'CLAUDE.md'
}

Write-Step 'dotfile links'
. (Join-Path $windowsDev 'scripts\dotfile-link.ps1')
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"
# The same targets setup-configs.ps1 makes on the laptop, minus the ones only a human uses, plus Claude Code's.
$agentLinks = [System.Collections.Generic.List[pscustomobject]]::new()
$agentLinks.Add([pscustomobject]@{
        Leaf   = 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
        Source = "$windowsDev\powershell\Microsoft.PowerShell_profile.ps1"
    })
$agentLinks.Add([pscustomobject]@{ Leaf = '.wezterm.lua'; Source = "$windowsDev\wezterm\.wezterm.lua" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\CLAUDE.md'; Source = "$windowsDev\claude\context.md" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\settings.json'; Source = "$windowsDev\claude\settings.json" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\agents'; Source = "$windowsDev\claude\agents" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\output-styles'; Source = "$windowsDev\claude\output-styles" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\rules'; Source = "$windowsDev\claude\rules" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\themes'; Source = "$windowsDev\claude\themes" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.config\terminus\config.yaml'; Source = "$windowsDev\terminus\config.yaml" })
foreach ($skill in Get-ChildItem "$windowsDev\claude\skills" -Directory) {
    $agentLinks.Add([pscustomobject]@{ Leaf = ".claude\skills\$($skill.Name)"; Source = $skill.FullName })
}
foreach ($agentLink in $agentLinks) { Link "$HOME\$($agentLink.Leaf)" $agentLink.Source $backupRoot }

#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Set up a fresh Windows machine: clone this repo, add its runtime checkout ~\.windows-dev, then run
  setup-packages.ps1 and setup-configs.ps1 from there in that order.

.DESCRIPTION
  Runs under Windows PowerShell 5.1 because a fresh machine has no pwsh 7 yet. setup-packages.ps1 installs it,
  and setup-configs.ps1 runs under it. Safe to rerun: the clone is skipped when the repo exists.
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

$runtimeCheckout = "$HOME\.windows-dev"
$hookMarker = '# Written by bootstrap.ps1.'
# perusal writes the agent's commits into ~\dev unreviewed, so nothing there runs elevated and no config links there.
# The runtime checkout holds committed code only: a reference-transaction hook checks it out at master each time master
# moves (commit, pull, reset, rebase). perusal writes work trees, never .git\hooks.
$hooksPathSetting = & $git -C $repo config --get core.hooksPath
if ($hooksPathSetting) { throw "core.hooksPath is $hooksPathSetting, so git would not run the hook in .git\hooks" }

if (-not (Test-Path $runtimeCheckout)) {
    & $git -C $repo worktree add --detach $runtimeCheckout master
    if ($LASTEXITCODE -ne 0) { throw "git worktree add $runtimeCheckout failed with exit code $LASTEXITCODE" }
}

$commonDir = & $git -C $repo rev-parse --path-format=absolute --git-common-dir
if ($LASTEXITCODE -ne 0) { throw "git rev-parse --git-common-dir in $repo failed with exit code $LASTEXITCODE" }
$hookPath = Join-Path $commonDir 'hooks\reference-transaction'
if ((Test-Path -LiteralPath $hookPath) -and -not (Select-String -LiteralPath $hookPath -SimpleMatch $hookMarker -Quiet)) {
    throw "$hookPath already holds another hook. Merge the one this script writes into it by hand"
}
# git runs hooks with Git for Windows' sh, which needs LF line ends. Hooks inherit GIT_DIR and GIT_INDEX_FILE, which
# would point git -C at this repository instead of the runtime checkout.
$hook = @(
    '#!/bin/sh'
    $hookMarker
    'test "$1" = committed || exit 0'
    "grep ' refs/heads/master$' >/dev/null || exit 0"
    'unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX'
    "exec git -C '$($runtimeCheckout.Replace('\', '/'))' checkout --quiet --detach master"
) -join "`n"
[IO.File]::WriteAllText($hookPath, "$hook`n", [Text.UTF8Encoding]::new($false))
Write-Host "$runtimeCheckout follows master through $hookPath" -ForegroundColor Cyan

& "$runtimeCheckout\scripts\host\setup-packages.ps1"

& $pwsh -NoProfile -File "$runtimeCheckout\scripts\host\setup-configs.ps1" -Layout $Layout
if ($LASTEXITCODE -ne 0) { throw "setup-configs.ps1 failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Left to do by hand, see README.md: Ziti Desktop Edge, thide, VsVim, new-agent-vm.ps1." -ForegroundColor Yellow

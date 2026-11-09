<#
.SYNOPSIS
  Add the runtime checkout ~\.windows-dev, a detached work tree of this repository that follows master, for the
  laptop to link its configs from and run its scripts from.

.DESCRIPTION
  perusal mirrors the agent's uncommitted edits into ~\dev\windows-dev, so a config linked from there, or a script
  run from there, would run the agent's code before review. The runtime checkout holds committed code only: a
  reference-transaction hook in this repository checks it out at master each time master moves (commit, pull, reset,
  rebase). perusal writes work trees, never .git\hooks.

  Runs under Windows PowerShell 5.1 too, since bootstrap.ps1 calls it before pwsh is installed. Safe to rerun. Run
  setup-configs.ps1 from the runtime checkout afterwards, so the links point there.
#>
param()
$ErrorActionPreference = 'Stop'
$git = "$env:ProgramFiles\Git\cmd\git.exe"
$repo = Split-Path $PSScriptRoot -Parent
$runtimeCheckout = Join-Path $HOME '.windows-dev'
$hookMarker = '# Written by scripts/add-runtime-checkout.ps1.'

$hooksPathSetting = & $git -C $repo config --get core.hooksPath
if ($hooksPathSetting) { throw "core.hooksPath is $hooksPathSetting, so git would not run the hook in .git\hooks" }

if (-not (Test-Path -LiteralPath $runtimeCheckout)) {
    & $git -C $repo worktree add --detach $runtimeCheckout master
    if ($LASTEXITCODE -ne 0) { throw "git worktree add $runtimeCheckout failed (exit $LASTEXITCODE)" }
}

$commonDir = & $git -C $repo rev-parse --path-format=absolute --git-common-dir
if ($LASTEXITCODE -ne 0) { throw "git rev-parse --git-common-dir in $repo failed (exit $LASTEXITCODE)" }
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
Write-Host "$runtimeCheckout follows master through $hookPath"

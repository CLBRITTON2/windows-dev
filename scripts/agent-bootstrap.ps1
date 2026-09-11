#Requires -Version 7
<#
.SYNOPSIS
  Prepare the agent account's own home. Runs as the agent, launched by scripts/setup-agent-account.ps1.

.DESCRIPTION
  Junctions <agent home>\dev onto the owner's dev root so the ~/dev paths in the shared settings.json resolve
  under both accounts, puts the Claude Code install dir on the account's persistent PATH (the installer only
  sets it for the session it runs in), marks the owner's repos safe for git, and installs Claude Code.

  Symlinks are not created here. The account has no SeCreateSymbolicLinkPrivilege, so its dotfile links are
  made by the elevated caller. Junctions need no privilege, hence the one below.

  Signals completion by writing $OwnerDevRoot\.agent-bootstrap-complete, which the caller polls for because
  runas returns as soon as it has spawned the child.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OwnerDevRoot
)

$ErrorActionPreference = 'Stop'
$binDir = "$HOME\.local\bin"

Write-Host "agent-bootstrap as $env:USERNAME" -ForegroundColor Cyan

if (-not (Test-Path "$HOME\dev")) {
    New-Item -ItemType Junction -Path "$HOME\dev" -Target $OwnerDevRoot | Out-Null
    Write-Host "  junction: $HOME\dev -> $OwnerDevRoot"
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
    Write-Host "  PATH += $binDir"
}

# The repos are owned by the other account, so git treats them as unsafe without this.
if ((git config --global --get-all safe.directory) -notcontains '*') {
    git config --global --add safe.directory '*'
    Write-Host "  git safe.directory = *"
}

if (-not (Test-Path "$binDir\claude.exe")) {
    Write-Host "  installing Claude Code"
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
}

'ok' | Set-Content -LiteralPath "$OwnerDevRoot\.agent-bootstrap-complete"
Write-Host "agent-bootstrap done" -ForegroundColor Green

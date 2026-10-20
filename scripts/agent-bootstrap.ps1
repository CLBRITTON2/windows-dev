#Requires -Version 7
<#
.SYNOPSIS
  Prepare the agent account's own home. Runs as the agent, launched by setup-claude.ps1.

.DESCRIPTION
  Junctions <agent home>\dev onto the owner's dev root so the ~/dev paths in the shared settings.json resolve
  under both accounts, puts the Claude Code install dir on the account's persistent PATH (the installer only
  sets it for the session it runs in), marks the owner's repos safe for git, installs Claude Code and herdr, and
  links this repo's herdr focus-file plugin.

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
# The installer's stable alias. The release folder it puts on PATH changes with every herdr version.
$herdr = "$env:LOCALAPPDATA\Programs\Herdr\bin\herdr.exe"
$focusPluginId = 'windows-dev.focus-file'
$focusPlugin = "$OwnerDevRoot\windows-dev\herdr\focus-file"

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

# The owner keeps CLAUDE.md links untracked in every repo, so git status would list them in each one.
$gitIgnore = "$HOME\.config\git\ignore"
if (-not (Test-Path $gitIgnore) -or (Get-Content -LiteralPath $gitIgnore) -notcontains 'CLAUDE.md') {
    New-Item -ItemType Directory -Force -Path (Split-Path $gitIgnore) | Out-Null
    Add-Content -LiteralPath $gitIgnore -Value 'CLAUDE.md'
    Write-Host "  git global ignore += CLAUDE.md"
}

if (-not (Test-Path "$binDir\claude.exe")) {
    Write-Host "  installing Claude Code"
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
}

if (-not (Test-Path $herdr)) {
    Write-Host "  installing herdr"
    Invoke-RestMethod https://herdr.dev/install.ps1 | Invoke-Expression
}

$plugins = & $herdr plugin list --json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "herdr plugin list failed with exit code $LASTEXITCODE" }
if ($plugins.result.plugins.plugin_id -notcontains $focusPluginId) {
    & $herdr plugin link $focusPlugin
    if ($LASTEXITCODE -ne 0) { throw "herdr plugin link $focusPlugin failed with exit code $LASTEXITCODE" }
    Write-Host "  herdr plugin linked: $focusPlugin"
}

'ok' | Set-Content -LiteralPath "$OwnerDevRoot\.agent-bootstrap-complete"
Write-Host "agent-bootstrap done" -ForegroundColor Green

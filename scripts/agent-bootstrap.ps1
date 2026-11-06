#Requires -Version 7
<#
.SYNOPSIS
  Prepare the agent account's own home. Runs as the agent in the agent VM, started by agent-vm-bootstrap.ps1.

.DESCRIPTION
  Junctions <agent home>\dev onto the owner's dev root so the ~/dev paths in the shared settings.json resolve
  under both accounts, puts the Claude Code install dir on the account's persistent PATH (the installer only
  sets it for the session it runs in), marks the owner's repos safe for git, installs Claude Code and herdr, and
  links this repo's herdr focus-file plugin.

  Also links the account's dotfiles from this repo.
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
$repo = Split-Path $PSScriptRoot -Parent
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$repo\scripts\dotfile-link.ps1"

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
    # A child scope, since the installer turns on Set-StrictMode, which then breaks the plugin list read below.
    & ([scriptblock]::Create((Invoke-RestMethod https://herdr.dev/install.ps1)))
}

$plugins = & $herdr plugin list --json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "herdr plugin list failed with exit code $LASTEXITCODE" }
if ($plugins.result.plugins.plugin_id -notcontains $focusPluginId) {
    & $herdr plugin link $focusPlugin
    if ($LASTEXITCODE -ne 0) { throw "herdr plugin link $focusPlugin failed with exit code $LASTEXITCODE" }
    Write-Host "  herdr plugin linked: $focusPlugin"
}

# The same targets setup-configs.ps1 makes for the owner, minus the ones only a human uses.
$agentLinks = [System.Collections.Generic.List[pscustomobject]]::new()
$agentLinks.Add([pscustomobject]@{
        Leaf   = 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
        Source = "$repo\powershell\Microsoft.PowerShell_profile.ps1"
    })
$agentLinks.Add([pscustomobject]@{ Leaf = '.wezterm.lua'; Source = "$repo\wezterm\.wezterm.lua" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\CLAUDE.md'; Source = "$repo\claude\context.md" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\settings.json'; Source = "$repo\claude\settings.json" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\agents'; Source = "$repo\claude\agents" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\output-styles'; Source = "$repo\claude\output-styles" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\rules'; Source = "$repo\claude\rules" })
$agentLinks.Add([pscustomobject]@{ Leaf = '.claude\themes'; Source = "$repo\claude\themes" })
foreach ($skill in Get-ChildItem "$repo\claude\skills" -Directory) {
    $agentLinks.Add([pscustomobject]@{ Leaf = ".claude\skills\$($skill.Name)"; Source = $skill.FullName })
}
foreach ($l in $agentLinks) { Link "$HOME\$($l.Leaf)" $l.Source $backupRoot }

Write-Host "agent-bootstrap done" -ForegroundColor Green

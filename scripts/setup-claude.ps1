#Requires -Version 7
<#
.SYNOPSIS
  Create the unprivileged Windows account Claude Code runs under, scope what it can touch, and set up its home.

.DESCRIPTION
  Needs an elevated shell. Safe to rerun.

  The account gets Modify on ~/dev only. Its own profile stays private and yours stays opaque to it (no
  listing, no reading .ssh, .aws, .claude, browser data). Every .git directory under ~/dev is denied write, so
  add, commit, checkout, and every other ref or index mutation fail for the account while you keep full access.
  This repo's dotfile link targets and setup scripts are denied write too, because they execute as you or
  elevated. The E: drive is denied outright.

  Then runs scripts/agent-bootstrap.ps1 as the account (runas prompts for the password it just set, once, and
  saves it for the claude function in the PowerShell profile), which also links the account's dotfiles.

  Left to do by hand afterwards, both interactive: claude then /login in an agent session, and gh auth login
  with a read-only PAT.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) { throw "needs an elevated shell" }

$account = 'claude'
$devRoot = "$HOME\dev"
$denyDrives = @('E:\')
$repo = Split-Path $PSScriptRoot -Parent
$bootstrap = "$repo\scripts\agent-bootstrap.ps1"
$marker = "$devRoot\.agent-bootstrap-complete"

$developerMode = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
    AllowDevelopmentWithoutDevLicense -ErrorAction Ignore
if ($developerMode -ne 1) {
    throw "Developer Mode is off, and agent-bootstrap.ps1 needs it to link the account's dotfiles. Run setup-packages.ps1 first"
}

# Depth 2 reaches ~/dev/<repo>/.git and ~/dev/<org>/<repo>/.git. Submodule .git entries are files and skipped.
$gitDirs = Get-ChildItem $devRoot -Directory -Recurse -Depth 2 -Force -Filter .git |
    Select-Object -ExpandProperty FullName

# Run as the owner (linked by setup-configs.ps1 or launched from the profile or GlazeWM) or run elevated
# during setup. They sit under the ~/dev grant, so the write bits have to come back off explicitly. A directory
# entry covers everything under it.
$ownerExecPaths = @(
    "$repo\powershell\Microsoft.PowerShell_profile.ps1"
    "$repo\wezterm\.wezterm.lua"
    "$repo\glazewm\config_single.yaml"
    "$repo\glazewm\config_dual.yaml"
    "$repo\glazewm\winkey-fix.ahk"
    "$repo\glazewm\switch-layout.ps1"
    "$repo\vscode\settings.json"
    "$repo\vscode\keybindings.json"
    "$repo\visualstudio\_vsvimrc"
    "$repo\windows-terminal\settings.json"
    "$repo\bootstrap.ps1"
    "$repo\scripts\setup-packages.ps1"
    "$repo\scripts\setup-configs.ps1"
    "$repo\scripts\setup-claude.ps1"
    "$repo\scripts\dotfile-link.ps1"
    "$repo\scripts\update-ziti-repos.ps1"
    "$repo\winget\packages.json"
    "$repo\intarsia"
    "$repo\perusal\config.json"
    "$repo\carronade\config.toml"
)
$missing = @($ownerExecPaths | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing) { throw "owner-exec path missing, fix the list: $($missing -join ', ')" }

# Without this the account could rename a parent directory aside and recreate it with its own copy of a denied
# file at the same path. Deny is this-folder-only so the directory's other contents stay editable.
$ownerExecAncestors = $ownerExecPaths |
    ForEach-Object {
        $dir = Split-Path $_ -Parent
        while ($dir.StartsWith($devRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $dir
            $dir = Split-Path $dir -Parent
        }
    } |
    Sort-Object -Unique |
    Where-Object { $_ -notin $ownerExecPaths }

# An owner holds WRITE_DAC whatever a deny says, and Edit replaces a file through a rename, so whatever the agent
# once wrote under a protected path stays its own until ownership comes back here. Get-ChildItem lists a junction
# without entering it (icacls /T would follow it), and any link stops the run before an elevated icacls acts on it.
$protectedRoots = @(@($gitDirs) + $ownerExecPaths + $ownerExecAncestors |
        ForEach-Object { Get-Item -LiteralPath $_ -Force })
$protectedItems = $protectedRoots + @(
    $protectedRoots |
        Where-Object { $_.PSIsContainer -and -not $_.LinkType -and $_.FullName -notin $ownerExecAncestors } |
        Get-ChildItem -Recurse -Force
)
# A hard link (a local clone makes them in .git\objects) names the same file, so icacls cannot be redirected through it.
$links = @($protectedItems | Where-Object LinkType -In 'Junction', 'SymbolicLink' | ForEach-Object FullName)
if ($links) { throw "link under a protected path, check where it points and remove it: $($links -join ', ')" }
$owner = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$agentSid = (Get-LocalUser -Name $account -ErrorAction Ignore).SID
if ($agentSid) {
    $agentOwned = @($protectedItems |
            Where-Object { (Get-Acl -LiteralPath $_.FullName).GetOwner([Security.Principal.SecurityIdentifier]) -eq $agentSid } |
            ForEach-Object FullName)
} else {
    $agentOwned = @()
}

# The .git deny lists write bits explicitly: the simple (W) includes SYNCHRONIZE, which every open requests, so
# it would block reads too and git would not see the repo. /remove:d first keeps a rerun from stacking ACEs.
$aclSteps = [System.Collections.Generic.List[string[]]]::new()
$aclSteps.Add(@($devRoot, '/grant', "${account}:(OI)(CI)(M)"))
foreach ($item in $agentOwned) { $aclSteps.Add(@($item, '/setowner', $owner, '/L')) }
foreach ($g in $gitDirs) {
    $aclSteps.Add(@($g, '/remove:d', $account))
    $aclSteps.Add(@($g, '/deny', "${account}:(OI)(CI)(WD,AD,WEA,WA,DE,DC)"))
}
foreach ($p in $ownerExecPaths) {
    $inherit = if (Test-Path $p -PathType Container) { '(OI)(CI)' } else { '' }
    $aclSteps.Add(@($p, '/remove:d', $account))
    $aclSteps.Add(@($p, '/deny', "${account}:${inherit}(WD,AD,WEA,WA,DE,DC)"))
}
foreach ($a in $ownerExecAncestors) {
    $aclSteps.Add(@($a, '/remove:d', $account))
    $aclSteps.Add(@($a, '/deny', "${account}:(DE)"))
}
foreach ($d in $denyDrives) { $aclSteps.Add(@($d, '/deny', "${account}:(OI)(CI)(F)")) }

$bootstrapArgs = "`"$env:ProgramFiles\PowerShell\7\pwsh.exe`" -NoLogo -NoProfile -File `"$bootstrap`" -OwnerDevRoot `"$devRoot`""

Write-Host "setup-agent-account" -ForegroundColor Cyan
Write-Host "  account    : $account (standard user, group Users only)"
Write-Host "  dev root   : $devRoot (Modify)"
Write-Host "  .git denied: $($gitDirs.Count) repos"
Write-Host "  write denied: $($ownerExecPaths.Count) owner-exec paths, $($ownerExecAncestors.Count) parent dirs"
Write-Host "  owner reset: $($agentOwned.Count) agent-owned items under protected paths"
Write-Host "  drives     : $($denyDrives -join ', ') (denied)"
Write-Host ""

if (-not (Get-LocalUser -Name $account -ErrorAction Ignore)) {
    $password = Read-Host "choose a password for new account $account" -AsSecureString
    New-LocalUser -Name $account -Password $password -PasswordNeverExpires -AccountNeverExpires | Out-Null
    Add-LocalGroupMember -Group Users -Member $account
}

foreach ($s in $aclSteps) {
    Write-Host ("icacls " + ($s -join ' ')) -ForegroundColor DarkGray
    & icacls @s
    if ($LASTEXITCODE -ne 0) { throw "icacls failed (exit $LASTEXITCODE): $($s -join ' ')" }
}

# runas is the only launcher that gives the account a real profile: a first logon through
# Start-Process -Credential landed in a temporary one and the junction vanished with it.
Remove-Item $marker -Force -ErrorAction Ignore
Write-Host "running agent-bootstrap as $account (enter its password if runas asks)" -ForegroundColor Cyan
& runas /user:$account /savecred $bootstrapArgs
if ($LASTEXITCODE -ne 0) { throw "runas failed (exit $LASTEXITCODE)" }

# runas returns as soon as it has spawned the child, so wait on the marker the bootstrap writes. The Claude
# Code download dominates the runtime on a fresh machine.
$deadline = (Get-Date).AddMinutes(10)
while (-not (Test-Path $marker)) {
    if ((Get-Date) -gt $deadline) {
        throw "agent-bootstrap did not finish. Run it by hand: runas /user:$account /savecred `"$bootstrapArgs`""
    }
    Start-Sleep -Seconds 2
}
Remove-Item $marker -Force

Write-Host ""
Write-Host 'done. two interactive steps are left, both inside an agent session (claude in a new shell):' -ForegroundColor Green
Write-Host "  /login"
Write-Host "  gh auth login   # read-only PAT"

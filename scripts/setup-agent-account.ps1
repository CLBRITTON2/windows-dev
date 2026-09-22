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
  saves it for the claude function in the PowerShell profile) and links the account's dotfiles from here,
  because the account itself has no privilege to create symlinks.

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
$bootstrap = "$PSScriptRoot\agent-bootstrap.ps1"
$marker = "$devRoot\.agent-bootstrap-complete"
$backupRoot = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"

. "$PSScriptRoot\dotfile-link.ps1"

# Depth 2 reaches ~/dev/<repo>/.git and ~/dev/<org>/<repo>/.git. Submodule .git entries are files and skipped.
# The agents repo stays writable: /lessons-learned commits context files as the account (push stays with the owner).
$gitDirs = Get-ChildItem $devRoot -Directory -Recurse -Depth 2 -Force -Filter .git |
    Select-Object -ExpandProperty FullName |
    Where-Object { $_ -ne "$devRoot\agents\.git" }

# Run as the owner (linked by setup-configs.ps1 or launched from the profile, GlazeWM, or Zebar) or run elevated
# during setup. They sit under the ~/dev grant, so the write bits have to come back off explicitly. A directory
# entry covers everything under it.
$ownerExecPaths = @(
    "$repo\powershell\Microsoft.PowerShell_profile.ps1"
    "$repo\wezterm\.wezterm.lua"
    "$repo\glazewm\config_laptop.yaml"
    "$repo\glazewm\config_kinesis.yaml"
    "$repo\glazewm\config_desktop.yaml"
    "$repo\glazewm\winkey-fix.ahk"
    "$repo\glazewm\sleep.ahk"
    "$repo\vscode\settings.json"
    "$repo\vscode\keybindings.json"
    "$repo\visualstudio\_vsvimrc"
    "$repo\windows-terminal\settings.json"
    "$repo\zebar"
    "$repo\setup-configs.ps1"
    "$repo\bootstrap.ps1"
    "$repo\scripts\setup-agent-account.ps1"
    "$repo\scripts\dotfile-link.ps1"
    "$repo\scripts\update-ziti-repos.ps1"
    "$repo\winget\packages.json"
)

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

# /C keeps going past WSL-made symlinks (a .venv lib64), which icacls cannot enumerate and otherwise exits 1920 on.
# The .git deny lists write bits explicitly: the simple (W) includes SYNCHRONIZE, which every open requests, so
# it would block reads too and git would not see the repo. /remove:d first keeps a rerun from stacking ACEs.
$aclSteps = [System.Collections.Generic.List[string[]]]::new()
$aclSteps.Add(@($devRoot, '/grant', "${account}:(OI)(CI)(M)", '/T', '/C'))
foreach ($g in $gitDirs) {
    $aclSteps.Add(@($g, '/remove:d', $account))
    $aclSteps.Add(@($g, '/deny', "${account}:(OI)(CI)(WD,AD,WEA,WA,DE,DC)"))
}
foreach ($p in $ownerExecPaths) {
    if (-not (Test-Path $p)) { throw "owner-exec path missing, fix the list: $p" }
    $inherit = if (Test-Path $p -PathType Container) { '(OI)(CI)' } else { '' }
    $aclSteps.Add(@($p, '/remove:d', $account))
    $aclSteps.Add(@($p, '/deny', "${account}:${inherit}(WD,AD,WEA,WA,DE,DC)"))
}
foreach ($a in $ownerExecAncestors) {
    $aclSteps.Add(@($a, '/remove:d', $account))
    $aclSteps.Add(@($a, '/deny', "${account}:(DE)"))
}
foreach ($d in $denyDrives) { $aclSteps.Add(@($d, '/deny', "${account}:(OI)(CI)(F)")) }

# Everything the agent needs in its own home. It reads the repo through the ~/dev grant, so these are the same
# targets setup-configs.ps1 makes for you, minus the ones only a human uses.
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
foreach ($skill in Get-ChildItem "$repo\claude\skills" -Directory) {
    $agentLinks.Add([pscustomobject]@{ Leaf = ".claude\skills\$($skill.Name)"; Source = $skill.FullName })
}

$bootstrapArgs = "pwsh -NoLogo -NoProfile -File `"$bootstrap`" -OwnerDevRoot `"$devRoot`""

Write-Host "setup-agent-account" -ForegroundColor Cyan
Write-Host "  account    : $account (standard user, group Users only)"
Write-Host "  dev root   : $devRoot (Modify)"
Write-Host "  .git denied: $($gitDirs.Count) repos"
Write-Host "  write denied: $($ownerExecPaths.Count) owner-exec paths, $($ownerExecAncestors.Count) parent dirs"
Write-Host "  drives     : $($denyDrives -join ', ') (denied)"
Write-Host "  home links : $($agentLinks.Count)"
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

$sid = (Get-LocalUser -Name $account).SID.Value
$agentHome = (Get-CimInstance Win32_UserProfile -Filter "SID='$sid'").LocalPath
if (-not $agentHome) { throw "no profile directory for $account even though bootstrap reported success" }

Write-Host "linking $agentHome" -ForegroundColor Cyan
foreach ($l in $agentLinks) { Link "$agentHome\$($l.Leaf)" $l.Source $backupRoot }

Write-Host ""
Write-Host 'done. two interactive steps are left, both inside an agent session (claude in a new shell):' -ForegroundColor Green
Write-Host "  /login"
Write-Host "  gh auth login   # read-only PAT"

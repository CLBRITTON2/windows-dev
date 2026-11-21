#Requires -Version 7
<#
.SYNOPSIS
  Turn on zen mode in the agent VM's herdr session, then attach to it in a new WezTerm window.

.DESCRIPTION
  Win+A runs this. herdr has no client-attach event, so the zen plugin's on action runs over ssh before the attach.
  When the VM's herdr server is not running, the invoke fails and the attach starts the server: zen mode then comes
  back only if it was on when the server stopped. herdr stays the direct child of a one-pane WezTerm, the only shape
  rallypoint restores, like the profile's herdr function.
#>

$ErrorActionPreference = 'Stop'
$invokeOutput = ssh claude-vm '& "$env:LOCALAPPDATA\Programs\Herdr\bin\herdr.exe" plugin action invoke on --plugin windows-dev.zen' 2>&1
$invokeExitCode = $LASTEXITCODE
Start-Process "$env:ProgramFiles\WezTerm\wezterm-gui.exe" -ArgumentList @(
    'start', '--', "$env:LOCALAPPDATA\Programs\Herdr\bin\herdr.exe", '--remote', 'claude-vm', '--remote-keybindings',
    'server')
if ($invokeExitCode -ne 0) {
    throw "herdr plugin action invoke on --plugin windows-dev.zen in claude-vm exited $invokeExitCode`: $invokeOutput"
}

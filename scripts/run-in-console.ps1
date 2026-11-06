#Requires -Version 7
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Run a PowerShell script elevated in the desktop session of the current user, and exit with its exit code.

.DESCRIPTION
  An ssh key logon has no desktop and no DPAPI, so UI tests and ziti-edge-tunnel fail in it. In the agent VM
  new-agent-vm.ps1 logs claude on to the console at boot, and this runs -ScriptPath there through a scheduled task,
  writing all its output to -LogPath. It waits for the script to finish.
#>
param(
    [Parameter(Mandatory)] [string] $ScriptPath,
    [Parameter(Mandatory)] [string] $LogPath
)
$ErrorActionPreference = 'Stop'
$desktopShell = Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue |
    Where-Object UserName -eq ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
if (-not $desktopShell) { throw "$env:USERNAME is not logged on to a desktop, so a task in its session cannot start" }

$taskName = "run-in-console-$PID"
$command = "& '$ScriptPath' *> '$LogPath'; exit `$LASTEXITCODE"
$action = New-ScheduledTaskAction -Execute "$env:ProgramFiles\PowerShell\7\pwsh.exe" -Argument "-NoProfile -Command `"$command`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
# A VM sees the host's battery, and without these the task stays Queued while the laptop is unplugged.
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings | Out-Null
try {
    Start-ScheduledTask -TaskName $taskName
    do { Start-Sleep -Seconds 2 } while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready')
    $exitCode = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
} finally {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
exit $exitCode

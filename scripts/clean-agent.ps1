#Requires -Version 7
<#
.SYNOPSIS
  Delete the scratch folders of Claude Code sessions idle for a week. Run as the agent account.

.DESCRIPTION
  Claude Code gives every session a folder at %TEMP%\claude\<project>\<session id> (its scratchpad and background
  task output) and never deletes it. A session is idle once neither its transcript under ~\.claude\projects nor any
  file in that folder has been written for $idleDays days and no running claude.exe was started with --resume on it.
  Idle folders are deleted, the rest are kept. Prints every session folder with its size and what happened to it.

  A resumed session finds its scratchpad gone, so anything worth keeping belongs in the agents repo context files.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$idleDays = 7
$scratchRoot = Join-Path $env:TEMP 'claude'
$transcriptRoot = Join-Path $HOME '.claude\projects'
$sessionIdPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

enum SessionAction {
    Delete
    KeepResumed
    KeepActive
}

class SessionFolder {
    [string]$Project
    [string]$SessionId
    [string]$Path
    [double]$SizeGB
    [datetime]$LastActive
    [SessionAction]$Action
}

function Get-ResumedSessionId {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'claude.exe'")
    $ids = @()
    foreach ($process in $processes) {
        $match = [regex]::Match([string]$process.CommandLine, '--resume\s+"?([0-9a-f-]{36})')
        if ($match.Success) {
            $ids += $match.Groups[1].Value
        }
    }
    return $ids
}

function Get-SessionFolder([string]$scratchRoot, [string]$transcriptRoot, [string[]]$resumedIds, [datetime]$cutoff) {
    $sessions = @()
    foreach ($projectDir in Get-ChildItem $scratchRoot -Directory -Force) {
        foreach ($sessionDir in Get-ChildItem $projectDir.FullName -Directory -Force) {
            if ($sessionDir.Name -notmatch $sessionIdPattern) {
                continue
            }
            $files = @(Get-ChildItem $sessionDir.FullName -Recurse -File -Force)
            $times = @($sessionDir.LastWriteTime) + @($files | ForEach-Object LastWriteTime)
            $transcript = Join-Path $transcriptRoot "$($projectDir.Name)\$($sessionDir.Name).jsonl"
            if (Test-Path -LiteralPath $transcript) {
                $times += (Get-Item -LiteralPath $transcript).LastWriteTime
            }

            $session = [SessionFolder]::new()
            $session.Project = $projectDir.Name
            $session.SessionId = $sessionDir.Name
            $session.Path = $sessionDir.FullName
            $session.SizeGB = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1GB, 2)
            $session.LastActive = ($times | Sort-Object -Descending | Select-Object -First 1)
            if ($sessionDir.Name -in $resumedIds) {
                $session.Action = [SessionAction]::KeepResumed
            } elseif ($session.LastActive -gt $cutoff) {
                $session.Action = [SessionAction]::KeepActive
            } else {
                $session.Action = [SessionAction]::Delete
            }
            $sessions += $session
        }
    }
    return $sessions
}

$sessions = @(Get-SessionFolder $scratchRoot $transcriptRoot (Get-ResumedSessionId) (Get-Date).AddDays(-$idleDays))
$idle = @($sessions | Where-Object Action -eq ([SessionAction]::Delete))
$sessions | Sort-Object SizeGB -Descending | Format-Table Project, SessionId, SizeGB, LastActive, Action -AutoSize

foreach ($session in $idle) {
    Remove-Item -LiteralPath $session.Path -Recurse -Force
}
$freedGB = [math]::Round(($idle | Measure-Object SizeGB -Sum).Sum, 2)
Write-Host "Deleted $($idle.Count) idle session folder(s), $freedGB GB" -ForegroundColor Green

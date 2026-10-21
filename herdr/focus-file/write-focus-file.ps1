<#
.SYNOPSIS
Writes the focused herdr pane's working directory, then every work tree its Claude session edited, one per line, to
~\dev\.herdr-focus.

.DESCRIPTION
herdr runs this as the agent account on startup and on every pane focus change. The owner's perusal follows the file
to review the repos the focused agent works in, so the file is the only thing that crosses from herdr to the owner.
perusal validates every path it reads from it, since the agent can write anything there.

herdr starts hooks without waiting for earlier ones to finish, so the run that writes last can belong to an older
focus change. Each run therefore reads the focus that is current while it holds a mutex, instead of trusting the
pane id in its event.
#>

$ErrorActionPreference = 'Stop'

$focusFile = Join-Path $HOME 'dev\.herdr-focus'
$editedDirs = Join-Path $env:LOCALAPPDATA 'windows-dev\edited-dirs'
$mutexTimeoutMs = 10000

function Get-FocusedPaneDirectories {
    $output = & $env:HERDR_BIN_PATH pane list
    if ($LASTEXITCODE -ne 0) {
        throw "herdr pane list exited ${LASTEXITCODE}: $output"
    }
    $reply = $output | ConvertFrom-Json
    $focused = @($reply.result.panes | Where-Object focused)
    if ($focused.Count -ne 1) {
        throw "herdr pane list has $($focused.Count) focused panes, want 1: $output"
    }
    $pane = $focused[0]
    if (-not $pane.cwd) {
        throw "herdr pane list returned no cwd for focused pane $($pane.pane_id): $output"
    }
    # record-edited-dir.ps1 writes these, named by the Claude session id herdr reports for the pane.
    if ($pane.agent_session.value -and (Test-Path -LiteralPath (Join-Path $editedDirs $pane.agent_session.value) -PathType Leaf)) {
        return @($pane.cwd) + [System.IO.File]::ReadAllLines((Join-Path $editedDirs $pane.agent_session.value))
    }
    return @($pane.cwd)
}

# Replace instead of overwrite, so a reader never sees a half-written list.
function Write-FocusFile([string]$path, [string[]]$directories) {
    $staging = "$path.tmp"
    [System.IO.File]::WriteAllText($staging, ($directories -join "`n"))
    [System.IO.File]::Move($staging, $path, $true)
}

$mutex = [System.Threading.Mutex]::new($false, 'Local\windows-dev.focus-file')
try {
    if (-not $mutex.WaitOne($mutexTimeoutMs)) {
        throw "another write-focus-file.ps1 held mutex Local\windows-dev.focus-file for over $mutexTimeoutMs ms"
    }
    try {
        Write-FocusFile $focusFile (Get-FocusedPaneDirectories)
    } finally {
        $mutex.ReleaseMutex()
    }
} finally {
    $mutex.Dispose()
}

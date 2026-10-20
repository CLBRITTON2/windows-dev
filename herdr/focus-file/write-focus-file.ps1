<#
.SYNOPSIS
Writes the working directory of the focused herdr pane to ~\dev\.herdr-focus.

.DESCRIPTION
herdr runs this as the agent account on startup and on every pane focus change. The owner's perusal follows the file
to review whichever repo the focused agent works in, so the file is the only thing that crosses from herdr to the
owner. perusal validates every path it reads from it, since the agent can write anything there.

herdr starts hooks without waiting for earlier ones to finish, so the run that writes last can belong to an older
focus change. Each run therefore reads the focus that is current while it holds a mutex, instead of trusting the
pane id in its event.
#>

$ErrorActionPreference = 'Stop'

$focusFile = Join-Path $HOME 'dev\.herdr-focus'
$mutexTimeoutMs = 10000

function Get-FocusedPaneDirectory {
    $output = & $env:HERDR_BIN_PATH pane list
    if ($LASTEXITCODE -ne 0) {
        throw "herdr pane list exited ${LASTEXITCODE}: $output"
    }
    $reply = $output | ConvertFrom-Json
    $focused = @($reply.result.panes | Where-Object focused)
    if ($focused.Count -ne 1) {
        throw "herdr pane list has $($focused.Count) focused panes, want 1: $output"
    }
    if (-not $focused[0].cwd) {
        throw "herdr pane list returned no cwd for focused pane $($focused[0].pane_id): $output"
    }
    return $focused[0].cwd
}

# Replace instead of overwrite, so a reader never sees a half-written path.
function Write-FocusFile([string]$path, [string]$directory) {
    $staging = "$path.tmp"
    [System.IO.File]::WriteAllText($staging, $directory)
    [System.IO.File]::Move($staging, $path, $true)
}

$mutex = [System.Threading.Mutex]::new($false, 'Local\windows-dev.focus-file')
try {
    if (-not $mutex.WaitOne($mutexTimeoutMs)) {
        throw "another write-focus-file.ps1 held mutex Local\windows-dev.focus-file for over $mutexTimeoutMs ms"
    }
    try {
        Write-FocusFile $focusFile (Get-FocusedPaneDirectory)
    } finally {
        $mutex.ReleaseMutex()
    }
} finally {
    $mutex.Dispose()
}

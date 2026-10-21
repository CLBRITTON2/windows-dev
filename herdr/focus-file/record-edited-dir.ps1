<#
.SYNOPSIS
Records the work tree of the file a Claude Code edit touched, keyed by the session, then refreshes ~\dev\.herdr-focus.

.DESCRIPTION
Claude Code runs this as a PostToolUse hook on Edit, Write and NotebookEdit. A session started in one repo can edit
others, so the session's file lists every work tree it edited, most recent first, and write-focus-file.ps1 writes them
after the pane's cwd. Edits outside a work tree under ~\dev, and sessions outside herdr, are not recorded, since
perusal follows only repos under ~\dev.
#>

$ErrorActionPreference = 'Stop'

$editedDirs = Join-Path $env:LOCALAPPDATA 'windows-dev\edited-dirs'
$agentDevDir = Join-Path $HOME 'dev'
$mutexTimeoutMs = 10000

# Claude Code also names files through the target of the ~\dev junction, the owner's dev folder.
function Get-AgentDevPath([string]$path) {
    $roots = @($agentDevDir) + @((Get-Item -LiteralPath $agentDevDir).Target | Where-Object { $_ })
    foreach ($root in $roots) {
        $prefix = $root.TrimEnd('\') + '\'
        if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return Join-Path $agentDevDir $path.Substring($prefix.Length)
        }
    }
    return ''
}

function Find-WorkTree([string]$dir) {
    $current = $dir
    while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current '.git')) {
            return $current
        }
        if ($current.TrimEnd('\') -ieq $agentDevDir.TrimEnd('\')) {
            return ''
        }
        $current = Split-Path -Parent $current
    }
    return ''
}

# Replace instead of overwrite, so a reader never sees a half-written list.
function Write-Atomically([string]$path, [string]$content) {
    $staging = "$path.tmp"
    [System.IO.File]::WriteAllText($staging, $content)
    [System.IO.File]::Move($staging, $path, $true)
}

function Read-Recorded([string]$sessionFile, [string]$workTree) {
    if (-not (Test-Path -LiteralPath $sessionFile -PathType Leaf)) {
        return @()
    }
    return @([System.IO.File]::ReadAllLines($sessionFile) | Where-Object { $_ -and $_ -ine $workTree })
}

if ($env:HERDR_ENV -ne '1') {
    exit 0
}

$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$payload = $reader.ReadToEnd() | ConvertFrom-Json

$sessionId = [guid]::Empty
if (-not [guid]::TryParse($payload.session_id, [ref]$sessionId)) {
    throw "PostToolUse payload session_id '$($payload.session_id)' is not a GUID, so it cannot name a file in $editedDirs"
}
if ($payload.tool_input.notebook_path) {
    $editedFile = $payload.tool_input.notebook_path
} else {
    $editedFile = $payload.tool_input.file_path
}
if (-not $editedFile) {
    throw "PostToolUse payload for $($payload.tool_name) has no tool_input.file_path or notebook_path: $($payload.tool_input | ConvertTo-Json -Compress)"
}

$editedDir = Get-AgentDevPath (Split-Path -Parent ([System.IO.Path]::GetFullPath($editedFile)))
if (-not $editedDir) {
    exit 0
}
# The agent commits its own context file edits in the same turn, so following them would show a clean repo.
if ($editedDir.StartsWith((Join-Path $agentDevDir 'agents') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    exit 0
}
$workTree = Find-WorkTree $editedDir
if (-not $workTree) {
    exit 0
}

[void][System.IO.Directory]::CreateDirectory($editedDirs)
$sessionFile = Join-Path $editedDirs $sessionId.ToString()
# Claude Code runs parallel edits' hooks at once, and each rewrites the session's list.
$mutex = [System.Threading.Mutex]::new($false, 'Local\windows-dev.edited-dirs')
try {
    if (-not $mutex.WaitOne($mutexTimeoutMs)) {
        throw "another record-edited-dir.ps1 held mutex Local\windows-dev.edited-dirs for over $mutexTimeoutMs ms"
    }
    try {
        Write-Atomically $sessionFile ((@($workTree) + (Read-Recorded $sessionFile $workTree)) -join "`n")
    } finally {
        $mutex.ReleaseMutex()
    }
} finally {
    $mutex.Dispose()
}
& (Join-Path $PSScriptRoot 'write-focus-file.ps1')

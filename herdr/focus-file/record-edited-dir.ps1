<#
.SYNOPSIS
Records the directory of the file a Claude Code edit touched, keyed by the session, then refreshes ~\dev\.herdr-focus.

.DESCRIPTION
Claude Code runs this as a PostToolUse hook on Edit, Write and NotebookEdit. A session started in one repo can edit
another, so write-focus-file.ps1 prefers the directory the focused pane's session last edited in over the pane's cwd.
Edits outside ~\dev, and sessions outside herdr, are not recorded, since perusal follows only repos under ~\dev.
#>

$ErrorActionPreference = 'Stop'

$editedDirs = Join-Path $env:LOCALAPPDATA 'windows-dev\edited-dirs'
$agentDevDir = Join-Path $HOME 'dev'

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

# Replace instead of overwrite, so a reader never sees a half-written path.
function Write-Atomically([string]$path, [string]$content) {
    $staging = "$path.tmp"
    [System.IO.File]::WriteAllText($staging, $content)
    [System.IO.File]::Move($staging, $path, $true)
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

[void][System.IO.Directory]::CreateDirectory($editedDirs)
Write-Atomically (Join-Path $editedDirs $sessionId.ToString()) $editedDir
& (Join-Path $PSScriptRoot 'write-focus-file.ps1')

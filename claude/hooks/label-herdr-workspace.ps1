<#
.SYNOPSIS
Asks Claude to label its herdr workspace with the task while the label is still the folder name herdr gave it.

.DESCRIPTION
Claude Code runs this as a UserPromptSubmit hook. Sessions start in the agents home repo, so herdr labels every
workspace with the same folder name, and an instruction in CLAUDE.md alone was skipped. The hook adds the request
next to the prompt instead, and stays silent once the label differs from the folder name. The herdr sidebar cuts a
label after about 19 characters, hence the 18 character limit.
#>

$ErrorActionPreference = 'Stop'

$maximumLabelLength = 18

if ($env:HERDR_ENV -ne '1') {
    exit 0
}
if (-not $env:HERDR_WORKSPACE_ID) {
    throw 'HERDR_ENV is 1 but HERDR_WORKSPACE_ID is empty, so the workspace to label is unknown'
}

$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$payload = $reader.ReadToEnd() | ConvertFrom-Json
if (-not $payload.cwd) {
    throw "UserPromptSubmit payload has no cwd: $($payload | ConvertTo-Json -Compress)"
}

$output = & $env:HERDR_BIN_PATH workspace get $env:HERDR_WORKSPACE_ID
if ($LASTEXITCODE -ne 0) {
    throw "herdr workspace get $env:HERDR_WORKSPACE_ID exited ${LASTEXITCODE}: $output"
}
$label = ($output | ConvertFrom-Json).result.workspace.label
if ($label -ne (Split-Path -Leaf $payload.cwd)) {
    exit 0
}

$request = "This herdr workspace is still labeled '$label', its folder name. Before answering, label it with the " +
    "task in at most $maximumLabelLength characters, naming the project and the work (`"ZET IT proxy`", " +
    "`"ZDEW UI tests`"): run ```"`$HERDR_BIN_PATH`" workspace rename `"`$HERDR_WORKSPACE_ID`" `"<label>`"``` with " +
    'the Bash tool. If the prompt does not yet say what the task is, skip it until a later prompt does.'
@{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $request } } |
    ConvertTo-Json -Compress

# Claude Code statusLine command: reads the session JSON on stdin, prints one ANSI-colored line.
# Payload fields: https://code.claude.com/docs/en/statusline

$ErrorActionPreference = 'Stop'

# Explicit UTF-8 both ways: the default console encoding is the OEM code page, which mangles paths and glyphs.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$status = $reader.ReadToEnd() | ConvertFrom-Json

$esc = [char]27

# Rose Pine as in intarsia/style.conf, in truecolor: the terminal's 16-color scheme maps green and cyan to one foam.
[string]$text = 'e0def4'
[string]$subtle = '908caa'
[string]$rose = 'ebbcba'
[string]$iris = 'c4a7e7'
[string]$foam = '9ccfd8'
[string]$gold = 'f6c177'
[string]$love = 'eb6f92'

# Nerd Font glyphs: powerline branch, clock, calendar, database, file-text.
[string]$iconBranch = [char]0xE0A0
[string]$iconFiveHour = [char]0xF017
[string]$iconWeek = [char]0xF073
[string]$iconContext = [char]0xF1C0
[string]$iconTranscript = [char]0xF15C
[string]$iconColor = $iris

function Get-Rgb([string]$hex) {
    [int]$red = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    [int]$green = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    [int]$blue = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    return "$red;$green;$blue"
}

function Format-Color([string]$hex, [string]$value) {
    return "$esc[38;2;$(Get-Rgb $hex)m$value$esc[0m"
}

function Get-PercentColor([double]$percent) {
    if ($percent -ge 85) { return $love }
    if ($percent -ge 60) { return $gold }
    return $text
}

function Format-Until([long]$epoch) {
    $seconds = [long]($epoch - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    if ($seconds -le 0) { return '' }
    if ($seconds -ge 3600) { return '{0}h{1:00}m' -f [math]::Floor($seconds / 3600), [math]::Floor(($seconds % 3600) / 60) }
    return '{0}m' -f [math]::Floor($seconds / 60)
}

function Format-Segment([string]$icon, [double]$percent, [string]$suffix) {
    [string]$value = Format-Color (Get-PercentColor $percent) "$([math]::Floor($percent))%"
    return "$(Format-Color $iconColor $icon) $value$(Format-Color $subtle $suffix)"
}

function Format-Size([long]$bytes) {
    if ($bytes -ge 1MB) { return '{0:0.0}M' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0}K' -f [math]::Floor($bytes / 1KB) }
    return "${bytes}B"
}

# Sums one column of `git diff --numstat`, skipping the "-" it prints for binary files.
function Measure-NumstatColumn([string[]]$numstat, [int]$column) {
    [long[]]$counts = @($numstat | ForEach-Object { "$_".Split("`t")[$column] } | Where-Object { $_ -match '^\d+$' })
    return [long]($counts | Measure-Object -Sum).Sum
}

# The payload carries only the model's window, so this reads the compact window as Claude Code does: the environment
# variable over the user settings key. A window saved by /autocompact or set in project settings is not seen here.
function Get-CompactWindow([long]$modelWindow) {
    [string]$fromEnvironment = $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW
    if ($fromEnvironment) { return [math]::Min([long]$fromEnvironment, $modelWindow) }
    $setting = (Get-Content -Raw -LiteralPath (Join-Path $HOME '.claude/settings.json') | ConvertFrom-Json).autoCompactWindow
    if ($setting -is [long]) { return [math]::Min($setting, $modelWindow) }
    # Unset or "auto": Claude Code tunes the window per model, and the payload does not carry it.
    return $modelWindow
}

# Sessions start in ~\dev\agents and edit other repos through absolute paths, so the location is the work tree
# record-edited-dir.ps1 listed first for the session, the one it edited most recently. ~\dev\agents is skipped, as in
# write-focus-file.ps1, since edits there are only context upkeep. A work tree prune-worktrees.ps1 removed stays in
# the list.
function Get-LastEditedDir([string]$sessionId, [string]$currentDir) {
    [string]$editedDirsFile = Join-Path $env:LOCALAPPDATA "windows-dev\edited-dirs\$sessionId"
    if (Test-Path -LiteralPath $editedDirsFile -PathType Leaf) {
        [string]$agentsDir = Join-Path $HOME 'dev\agents'
        [string]$lastEdited = [System.IO.File]::ReadAllLines($editedDirsFile) |
            Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
            Where-Object { $_ -ine $agentsDir } | Select-Object -First 1
        if ($lastEdited) { return $lastEdited }
    }
    return $currentDir
}

# <repo>/<folder> for a folder under ~\dev\worktrees\<repo path>\<folder>, the leaf for any other folder.
function Get-LocationName([string]$dir) {
    [string]$worktreesPrefix = (Join-Path $HOME 'dev\worktrees') + '\'
    if ($dir.StartsWith($worktreesPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        [string[]]$parts = $dir.Substring($worktreesPrefix.Length).TrimEnd('\').Split('\')
        if ($parts.Count -ge 2) { return "$($parts[-2])/$($parts[-1])" }
    }
    return Split-Path -Leaf $dir
}

# The zen view (calmpane) shows this file under its input. Rewritten in place, not renamed over: Windows refuses
# the rename while the zen view has the file open. The trailing newline tells the zen view the write is whole.
function Write-StatusLineFile([string]$sessionId, [string]$line) {
    [string]$statusLineDir = Join-Path $env:LOCALAPPDATA 'windows-dev\statusline'
    [void][System.IO.Directory]::CreateDirectory($statusLineDir)
    [byte[]]$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes("$line`n")
    $stream = [System.IO.File]::Open((Join-Path $statusLineDir $sessionId), [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
    } finally {
        $stream.Dispose()
    }
}

$sessionId = [guid]::Empty
if (-not [guid]::TryParse($status.session_id, [ref]$sessionId)) {
    throw "statusLine payload session_id '$($status.session_id)' is not a GUID, so it cannot name a file"
}

[string]$locationDir = Get-LastEditedDir $sessionId.ToString() $status.workspace.current_dir
[string]$branch = git --no-optional-locks -C $locationDir rev-parse --abbrev-ref HEAD 2>$null
[System.Collections.Generic.List[string]]$segments = [System.Collections.Generic.List[string]]::new()

[string]$location = Format-Color $rose (Get-LocationName $locationDir)
if ($branch) {
    $location += " $(Format-Color $iris "$iconBranch $branch")"
    # Staged and unstaged edits against HEAD. Untracked files are not counted.
    [string[]]$numstat = git --no-optional-locks -C $locationDir diff HEAD --numstat 2>$null
    [long]$added = Measure-NumstatColumn $numstat 0
    [long]$removed = Measure-NumstatColumn $numstat 1
    if ($added -gt 0 -or $removed -gt 0) {
        $location += " $(Format-Color $foam "+$added") $(Format-Color $love "-$removed")"
    }
}
$segments.Add($location)

$segments.Add((Format-Color $foam $status.model.display_name))

# rate_limits is absent for API-key sessions and until the first response of a subscription session.
$fiveHour = $status.rate_limits.five_hour
if ($null -ne $fiveHour) {
    [string]$until = Format-Until ([long]$fiveHour.resets_at)
    if ($until) { [string]$suffix = " $until" } else { [string]$suffix = '' }
    $segments.Add((Format-Segment $iconFiveHour ([double]$fiveHour.used_percentage) $suffix))
}
$sevenDay = $status.rate_limits.seven_day
if ($null -ne $sevenDay) {
    $segments.Add((Format-Segment $iconWeek ([double]$sevenDay.used_percentage) ''))
}

$context = $status.context_window
if ($null -ne $context.used_percentage) {
    [long]$used = $context.total_input_tokens
    [long]$window = Get-CompactWindow ([long]$context.context_window_size)
    [string]$tokens = '{0}k/{1}k' -f [math]::Floor($used / 1000), [math]::Floor($window / 1000)
    $segments.Add((Format-Segment $iconContext (100 * $used / $window) " $tokens"))
}

# A large transcript means slower resumes and more compaction.
[string]$transcript = $status.transcript_path
if ($transcript -and (Test-Path -LiteralPath $transcript)) {
    [long]$bytes = (Get-Item -LiteralPath $transcript).Length
    if ($bytes -ge 50MB) { [string]$color = $love }
    elseif ($bytes -ge 20MB) { [string]$color = $gold }
    else { [string]$color = $subtle }
    $segments.Add("$(Format-Color $iconColor $iconTranscript) $(Format-Color $color (Format-Size $bytes))")
}

$writer = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), [System.Text.UTF8Encoding]::new($false))
[string]$line = $segments -join (Format-Color $subtle '  │  ')
$writer.Write($line)
$writer.Flush()
Write-StatusLineFile $sessionId.ToString() $line

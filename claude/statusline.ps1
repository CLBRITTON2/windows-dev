# Claude Code statusLine command: reads the session JSON on stdin, prints one ANSI-colored line.
# Payload fields: https://code.claude.com/docs/en/statusline

$ErrorActionPreference = 'Stop'

# Explicit UTF-8 both ways: the default console encoding is the OEM code page, which mangles paths and glyphs.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$status = $reader.ReadToEnd() | ConvertFrom-Json

$esc = [char]27

# Rose Pine as in intarsia/style.conf, in truecolor: the terminal's 16-color scheme maps green and cyan to one foam.
[string]$base = '191724'
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

[string]$cwd = $status.workspace.current_dir
[string]$branch = git --no-optional-locks -C $cwd rev-parse --abbrev-ref HEAD 2>$null
[System.Collections.Generic.List[string]]$segments = [System.Collections.Generic.List[string]]::new()

[string]$location = Format-Color $rose (Split-Path -Leaf $cwd)
if ($branch) {
    $location += " $(Format-Color $iris "$iconBranch $branch")"
    # Staged and unstaged edits against HEAD. Untracked files are not counted.
    [string[]]$numstat = git --no-optional-locks -C $cwd diff HEAD --numstat 2>$null
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

# Absolute token thresholds, not percentages: every turn resends the whole context, so cost tracks raw size.
$context = $status.context_window
if ($null -ne $context.used_percentage) {
    [long]$used = $context.total_input_tokens
    [string]$tokens = '{0}k/{1}k' -f [math]::Floor($used / 1000), [math]::Floor($context.context_window_size / 1000)
    if ($used -ge 300000) {
        $segments.Add("$esc[1;38;2;$(Get-Rgb $base);48;2;$(Get-Rgb $love)m $iconContext $tokens  /compact or /clear $esc[0m")
    }
    elseif ($used -ge 200000) { $segments.Add("$esc[1m$(Format-Color $gold "$iconContext $tokens getting expensive")") }
    else { $segments.Add((Format-Segment $iconContext ([double]$context.used_percentage) " $tokens")) }
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
$writer.Write($segments -join (Format-Color $subtle '  │  '))
$writer.Flush()

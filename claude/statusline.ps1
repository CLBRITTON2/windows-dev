# Claude Code statusLine command: reads the session JSON on stdin, prints one ANSI-colored line.
# Payload fields: https://code.claude.com/docs/en/statusline

$ErrorActionPreference = 'Stop'

# Explicit UTF-8: the default console input encoding is the OEM code page, which mangles non-ASCII paths.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$status = $reader.ReadToEnd() | ConvertFrom-Json

$esc = [char]27
$separator = "$esc[90m  |$esc[0m"

function Get-PercentColor([double]$percent) {
    if ($percent -ge 85) { return 31 }
    if ($percent -ge 60) { return 33 }
    return 32
}

function Format-Until([long]$epoch) {
    $seconds = [long]($epoch - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    if ($seconds -le 0) { return '' }
    if ($seconds -ge 3600) { return '{0}h{1:00}m' -f [math]::Floor($seconds / 3600), [math]::Floor(($seconds % 3600) / 60) }
    return '{0}m' -f [math]::Floor($seconds / 60)
}

function Format-Segment([string]$label, [double]$percent, [string]$suffix) {
    $color = Get-PercentColor $percent
    return "$separator$esc[90m $label $esc[0m$esc[${color}m$([math]::Floor($percent))%$esc[0m$esc[90m$suffix$esc[0m"
}

function Format-Size([long]$bytes) {
    if ($bytes -ge 1MB) { return '{0:0.0}M' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0}K' -f [math]::Floor($bytes / 1KB) }
    return "${bytes}B"
}

[string]$cwd = $status.workspace.current_dir
[string]$branch = git --no-optional-locks -C $cwd rev-parse --abbrev-ref HEAD 2>$null
[System.Text.StringBuilder]$line = [System.Text.StringBuilder]::new()

[void]$line.Append("$esc[32m$(Split-Path -Leaf $cwd)$esc[0m ")
if ($branch) { [void]$line.Append("$esc[33m($branch)$esc[0m") }
[void]$line.Append("$separator$esc[36m $($status.model.display_name)$esc[0m")

# rate_limits is absent for API-key sessions and until the first response of a subscription session.
$fiveHour = $status.rate_limits.five_hour
if ($null -ne $fiveHour) {
    [string]$until = Format-Until ([long]$fiveHour.resets_at)
    [string]$suffix = if ($until) { " ($until)" } else { '' }
    [void]$line.Append((Format-Segment '5h' ([double]$fiveHour.used_percentage) $suffix))
}
$sevenDay = $status.rate_limits.seven_day
if ($null -ne $sevenDay) {
    [void]$line.Append((Format-Segment 'wk' ([double]$sevenDay.used_percentage) ''))
}

# Absolute token thresholds, not percentages: every turn resends the whole context, so cost tracks raw size.
$context = $status.context_window
if ($null -ne $context.used_percentage) {
    [long]$used = $context.total_input_tokens
    [string]$tokens = '{0}k/{1}k' -f [math]::Floor($used / 1000), [math]::Floor($context.context_window_size / 1000)
    if ($used -ge 300000) { [void]$line.Append("$separator$esc[1;97;41m  ctx $tokens  /compact or /clear  $esc[0m") }
    elseif ($used -ge 200000) { [void]$line.Append("$separator$esc[1;33m ctx $tokens getting expensive$esc[0m") }
    else { [void]$line.Append((Format-Segment 'ctx' ([double]$context.used_percentage) " $tokens")) }
}

# A large transcript means slower resumes and more compaction.
[string]$transcript = $status.transcript_path
if ($transcript -and (Test-Path -LiteralPath $transcript)) {
    [long]$bytes = (Get-Item -LiteralPath $transcript).Length
    [int]$color = if ($bytes -ge 50MB) { 31 } elseif ($bytes -ge 20MB) { 33 } else { 90 }
    [void]$line.Append("$separator$esc[${color}m tx $(Format-Size $bytes)$esc[0m")
}

[Console]::Out.Write($line.ToString())

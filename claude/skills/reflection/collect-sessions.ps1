#Requires -Version 7
<#
.SYNOPSIS
Boils the newest Claude Code session transcripts down to what the reflection skill reads: the user's prompts, the tool
calls that failed, the commands that were not installed, and how often each tool and executable ran.

.DESCRIPTION
Transcripts run to tens of MB, mostly tool output and API bookkeeping, so reading them whole would fill the context.
Reads ~/.claude/projects/*/*.jsonl (subagent transcripts live in subfolders and are skipped), newest first. A session
with fewer than two prompts is skipped, which also drops the session running the reflection.
#>

param(
    [Parameter(Mandatory)]
    [int]$SessionCount
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

class ToolCall {
    [string]$Name
    [string]$Input
}

function Format-Excerpt([string]$text, [int]$maxLength) {
    $oneLine = ($text -replace '\s+', ' ').Trim()
    if ($oneLine.Length -le $maxLength) {
        return $oneLine
    }
    return $oneLine.Substring(0, $maxLength) + ' [...]'
}

function Add-Count([System.Collections.Generic.Dictionary[string, int]]$counts, [string]$key) {
    $current = 0
    if ($counts.TryGetValue($key, [ref]$current)) {
        $counts[$key] = $current + 1
    } else {
        $counts[$key] = 1
    }
}

function Format-Counts([System.Collections.Generic.Dictionary[string, int]]$counts) {
    return ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 |
            ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '
}

function ContentText([object]$content) {
    if ($content -is [string]) {
        return $content
    }
    return (@($content) | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n"
}

$projectsDir = Join-Path $HOME '.claude\projects'
if (-not (Test-Path $projectsDir)) {
    throw "$projectsDir does not exist, so there are no transcripts to read"
}
[System.IO.FileInfo[]]$transcripts = @(Get-ChildItem -Path (Join-Path $projectsDir '*\*.jsonl') -File |
        Sort-Object LastWriteTimeUtc -Descending)
# bash "x: command not found", cmd "'x' is not recognized as an internal...", PowerShell "The term 'x' is not
# recognized".
$missingPattern = "(?:^|\n|: )(?<cmd>[\w.-]+): command not found|'(?<cmd>[^'\s]+)' is not recognized as"
$shellWords = @('for', 'do', 'done', 'if', 'then', 'else', 'elif', 'fi', 'while', 'case', 'esac', 'time', 'echo',
    'cd', 'export', 'test', '[', '{', '}', '(', ')')

$written = 0
foreach ($transcript in $transcripts) {
    if ($written -ge $SessionCount) {
        break
    }
    $title = ''
    $firstUtc = ''
    $lastUtc = ''
    $prompts = [System.Collections.Generic.List[string]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
    $toolCounts = [System.Collections.Generic.Dictionary[string, int]]::new()
    $executableCounts = [System.Collections.Generic.Dictionary[string, int]]::new()
    $missingCommands = [System.Collections.Generic.Dictionary[string, int]]::new()
    $toolCalls = [System.Collections.Generic.Dictionary[string, ToolCall]]::new()

    foreach ($line in [System.IO.File]::ReadLines($transcript.FullName)) {
        # Most lines are API bookkeeping, and parsing all of a 40 MB transcript takes minutes.
        if ($line.StartsWith('{"type":"ai-title"')) {
            $title = ($line | ConvertFrom-Json).aiTitle
            continue
        }
        if (-not ($line.Contains('"type":"user"') -or $line.Contains('"type":"assistant"'))) {
            continue
        }
        $record = $line | ConvertFrom-Json -Depth 64
        if ($record.isSidechain -or $null -eq $record.message) {
            continue
        }
        if ($firstUtc -eq '') {
            $firstUtc = $record.timestamp
        }
        $lastUtc = $record.timestamp

        if ($record.type -eq 'assistant') {
            foreach ($block in @($record.message.content) | Where-Object { $_.type -eq 'tool_use' }) {
                Add-Count $toolCounts $block.name
                if ($block.name -eq 'Bash' -or $block.name -eq 'PowerShell') {
                    $toolCalls[$block.id] = [ToolCall]@{ Name = $block.name; Input = $block.input.command }
                    $executables = [System.Collections.Generic.HashSet[string]]::new()
                    # Heredoc bodies and single-quoted strings (grep patterns, jq filters) hold words and pipes that are
                    # not commands.
                    $commandText = $block.input.command `
                        -replace "(?s)<<-?\s*['""]?(\w+)['""]?[^\n]*\n.*?\n\1(?=\s|$)", '' -replace "'[^']*'", "''"
                    foreach ($segment in [regex]::Split($commandText, '\|\||&&|[;|\n]|\$\(|`')) {
                        # Skip leading VAR=value assignments to reach the command word, which may be a quoted path.
                        $commandMatch = [regex]::Match($segment,
                            '^\s*(?:\w+=(?:"[^"]*"|\S*)\s+)*(?<word>"[^"]+"|[^\s"]+)')
                        if (-not $commandMatch.Success) {
                            continue
                        }
                        $commandWord = $commandMatch.Groups['word'].Value
                        # A bare assignment, or a script reached through a variable such as "$S/probe.ps1".
                        if ($commandWord -match '=|\$') {
                            continue
                        }
                        # Split-Path reads a word like "Foo::Bar" as a provider path and throws.
                        $executable = $commandWord.Trim('"', "'") -replace '^.*[\\/]', '' -replace '\.exe$', ''
                        if ($executable -match '^[\w.+-]+$' -and $executable -notin $shellWords) {
                            $executables.Add($executable) | Out-Null
                        }
                    }
                    foreach ($executable in $executables) {
                        Add-Count $executableCounts $executable
                    }
                } elseif ($null -ne $block.input.file_path) {
                    $toolCalls[$block.id] = [ToolCall]@{ Name = $block.name; Input = $block.input.file_path }
                } else {
                    $toolCalls[$block.id] = [ToolCall]@{
                        Name  = $block.name
                        Input = $block.input | ConvertTo-Json -Compress -Depth 3
                    }
                }
            }
            continue
        }

        if ($record.origin.kind -eq 'human') {
            $prompt = ContentText $record.message.content
            if (-not $prompt.StartsWith('<local-command') -and -not $prompt.StartsWith('<command-name>')) {
                $prompts.Add((Format-Excerpt $prompt 600))
            }
            continue
        }
        foreach ($block in @($record.message.content) | Where-Object { $_.type -eq 'tool_result' -and $_.is_error }) {
            $errorText = ContentText $block.content
            $call = $null
            if (-not $toolCalls.TryGetValue($block.tool_use_id, [ref]$call)) {
                $call = [ToolCall]@{ Name = '?'; Input = '' }
            }
            $failures.Add("$($call.Name) ``$(Format-Excerpt $call.Input 150)``: $(Format-Excerpt $errorText 250)")
            foreach ($match in [regex]::Matches($errorText, $missingPattern)) {
                Add-Count $missingCommands $match.Groups['cmd'].Value
            }
        }
    }

    if ($prompts.Count -lt 2) {
        continue
    }
    $written++
    "## $($transcript.Directory.Name) $($transcript.BaseName)"
    "$firstUtc to $lastUtc, title: $title"
    "Tools: $(Format-Counts $toolCounts)"
    "Executables: $(Format-Counts $executableCounts)"
    if ($missingCommands.Count -gt 0) {
        "Missing commands: $(Format-Counts $missingCommands)"
    }
    ''
    '### Prompts'
    $prompts | ForEach-Object { "- $_" }
    ''
    "### Failed tool calls ($($failures.Count))"
    $failures | ForEach-Object { "- $_" }
    ''
}
if ($written -eq 0) {
    throw "no transcript under $projectsDir has two or more prompts"
}

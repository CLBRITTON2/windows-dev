<#
.SYNOPSIS
Keeps Claude Code from ending a turn whose code edits break the rules in claude/rules/code.md.

.DESCRIPTION
Claude Code runs this as a Stop hook. It collects the successful Edit and Write calls since the last user prompt on
files the rules' paths: globs match, and has Haiku check the text they wrote against the rules in a nested claude -p
run. Findings come back as a block reason, which sends Claude back to fix them or say why a finding is wrong. A turn
already continuing because of a Stop hook is not checked again, so each turn gets one correction round.
#>

$ErrorActionPreference = 'Stop'
# Native output is decoded with the console code page (437 here), which garbles non-ASCII text in the findings.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$rulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'rules\code.md'
$attempts = 3

$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$payload = $reader.ReadToEnd() | ConvertFrom-Json
if ($payload.stop_hook_active) {
    exit 0
}

$rulesText = [System.IO.File]::ReadAllText($rulesPath)
$rulesParts = [regex]::Match($rulesText, '\A---\r?\n(?<head>.*?)\r?\n---\r?\n(?<body>.*)\z', 'Singleline')
if (-not $rulesParts.Success) {
    throw "$rulesPath does not start with a --- frontmatter block"
}
[string[]]$globs = @([regex]::Matches($rulesParts.Groups['head'].Value, '(?m)^\s*-\s*"(?<glob>[^"]+)"') |
    ForEach-Object { $_.Groups['glob'].Value })
if ($globs.Count -eq 0) {
    throw "$rulesPath frontmatter lists no quoted paths: globs"
}
[string[]]$pathPatterns = @($globs | ForEach-Object {
        $wildcards = [regex]::Escape($_) -replace '\\\*\\\*/', '(?:.*/)?' -replace '\\\*', '[^/]*'
        $alternatives = [regex]::Replace($wildcards, '\\\{([^}]*)\}', { param($m) "(?:$($m.Groups[1].Value -replace ',', '|'))" })
        "^$alternatives$"
    })

# Walk back to the prompt that started this turn, so earlier turns' edits are not checked again.
[string[]]$lines = [System.IO.File]::ReadAllLines($payload.transcript_path)
$turn = [System.Collections.Generic.List[psobject]]::new()
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if (-not $lines[$i]) {
        continue
    }
    $entry = $lines[$i] | ConvertFrom-Json
    $isToolResult = @($entry.message.content | Where-Object { $_.type -eq 'tool_result' }).Count -gt 0
    if ($entry.type -eq 'user' -and -not $entry.isMeta -and -not $isToolResult) {
        break
    }
    $turn.Insert(0, $entry)
}

[string[]]$failedIds = @($turn | ForEach-Object { $_.message.content } |
    Where-Object { $_.type -eq 'tool_result' -and $_.is_error } | ForEach-Object { $_.tool_use_id })
$codeEdits = @($turn | Where-Object { $_.type -eq 'assistant' } | ForEach-Object { $_.message.content } |
    Where-Object { $_.type -eq 'tool_use' -and $_.name -in 'Edit', 'Write' -and $_.id -notin $failedIds } |
    Where-Object {
        $path = $_.input.file_path -replace '\\', '/'
        @($pathPatterns | Where-Object { $path -match $_ }).Count -gt 0
    })
if ($codeEdits.Count -eq 0) {
    exit 0
}

$editText = ($codeEdits | ForEach-Object {
        if ($_.name -eq 'Write') {
            "### Write $($_.input.file_path)`n<new>`n$($_.input.content)`n</new>"
        }
        else {
            "### Edit $($_.input.file_path)`n<old>`n$($_.input.old_string)`n</old>`n<new>`n$($_.input.new_string)`n</new>"
        }
    }) -join "`n`n"
$systemPrompt = @"
You check code edits against a rule set. Each edit names a file, the text it replaced in <old> (absent for a whole-file
Write) and the text written in <new>. Judge only text that is new in <new>: a line also present in <old> is
pre-existing and never a violation. Report a violation only when the shown text clearly breaks a rule. Skip rules that
need code outside the shown text to judge, such as whether a function has one caller or whether logic exists
elsewhere. Quote the offending line exactly as written. Report nothing when no rule is clearly broken.

$($rulesParts.Groups['body'].Value)
"@

# Only project settings, from a folder with none, so the nested run loads no hooks (this one included).
Set-Location ([System.IO.Path]::GetTempPath())
for ($attempt = 1; ; $attempt++) {
    $output = $editText | & claude -p --model haiku --setting-sources project --tools '' --no-session-persistence `
        --system-prompt $systemPrompt --output-format json `
        --json-schema '{"type":"object","properties":{"violations":{"type":"array","items":{"type":"object","properties":{"file":{"type":"string"},"quote":{"type":"string"},"rule":{"type":"string"}},"required":["file","quote","rule"]}}},"required":["violations"]}'
    if ($LASTEXITCODE -eq 0) {
        break
    }
    if ($attempt -eq $attempts) {
        throw "claude -p rules check failed $attempts times, last exit code $LASTEXITCODE, output: $output"
    }
    [Console]::Error.WriteLine((@{ event = 'rules-check-retry'; attempt = $attempt; attempts = $attempts; exitCode = $LASTEXITCODE } | ConvertTo-Json -Compress))
}
$result = ($output -join "`n") | ConvertFrom-Json
if ($result.is_error -or $null -eq $result.structured_output) {
    throw "claude -p rules check returned no structured_output: $output"
}

$violations = @($result.structured_output.violations)
if ($violations.Count -eq 0) {
    exit 0
}
$findings = ($violations | ForEach-Object { "- $($_.file): ``$($_.quote)`` breaks: $($_.rule)" }) -join "`n"
@{
    decision = 'block'
    reason   = "A Haiku check against ~/.claude/rules/code.md flagged lines written this turn. Fix each one, or say in your reply why a finding is wrong:`n$findings"
} | ConvertTo-Json -Compress

<#
.SYNOPSIS
Sends the rule breaks in the lines an Edit or Write call just wrote back to Claude, before it writes its reply.

.DESCRIPTION
Claude Code runs this as a PostToolUse hook on Edit and Write. It lints the edited file with ast-grep and the rules in
claude/ast-grep, or for PowerShell with checks on the parser's syntax tree, since ast-grep has no PowerShell grammar.
Only findings on lines the call wrote are reported, so older code in the file is not held to claude/rules/code.md.
Findings come back as a block reason, which Claude sees right after the tool result.
#>

$ErrorActionPreference = 'Stop'
# Native output is decoded with the console code page (437 here), which garbles non-ASCII text in the findings.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

class LintFinding {
    [int]$Line
    [string]$Rule
    [string]$Text
}

[string[]]$powerShellExtensions = @('.ps1', '.psm1')
# The rule's own examples of generic words and ad hoc abbreviations, plus the usual fillers, or a single letter.
$genericNamePattern = '^([a-z]|found|status|props|added|data|result|tmp|temp|val|obj|vm|evt)$'

$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$payload = $reader.ReadToEnd() | ConvertFrom-Json
[string]$filePath = $payload.tool_input.file_path
[string]$extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
# Only repo code under either account's ~/dev, so throwaway scratchpad scripts are not held to the rules.
if (($filePath -replace '\\', '/') -notmatch '^[a-z]:/users/[^/]+/dev/') {
    exit 0
}
# The Edit tool writes LF in new_string even into a CRLF file.
[string]$fileText = [System.IO.File]::ReadAllText($filePath) -replace "`r`n", "`n"
$writtenLines = [System.Collections.Generic.HashSet[int]]::new()
if ($payload.tool_name -eq 'Write') {
    [int]$fileLineCount = $fileText.Split("`n").Count
    foreach ($lineNumber in 1..$fileLineCount) {
        [void]$writtenLines.Add($lineNumber)
    }
}
else {
    [string]$newText = $payload.tool_input.new_string -replace "`r`n", "`n"
    if (-not $newText.Trim()) {
        exit 0
    }
    [string[]]$newTextLines = $newText.Split("`n")
    # A line the edit only carried over from old_string was there before and is not the edit's to fix.
    $carriedOverLines = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            ($payload.tool_input.old_string -replace "`r`n", "`n").Split("`n") | ForEach-Object { $_.Trim() }))
    [int]$searchFrom = 0
    while (($matchIndex = $fileText.IndexOf($newText, $searchFrom, [System.StringComparison]::Ordinal)) -ge 0) {
        [int]$firstLine = $fileText.Substring(0, $matchIndex).Split("`n").Count
        for ($offset = 0; $offset -lt $newTextLines.Count; $offset++) {
            if (-not $carriedOverLines.Contains($newTextLines[$offset].Trim())) {
                [void]$writtenLines.Add($firstLine + $offset)
            }
        }
        $searchFrom = $matchIndex + $newText.Length
    }
    if ($searchFrom -eq 0) {
        throw "new_string of the Edit is not in $filePath anymore, so its lines cannot be linted"
    }
}

$findings = [System.Collections.Generic.List[LintFinding]]::new()
# Checked as text for every language, since a comment line looks the same in all of them. Markdown is skipped because
# its headings and rules are built from the same characters.
if ($extension -ne '.md') {
    [string[]]$fileLines = $fileText.Split("`n")
    foreach ($lineNumber in $writtenLines) {
        [string]$lineText = $fileLines[$lineNumber - 1]
        if ($lineText -match '^\s*(//|#|/\*|\*|<#)' -and $lineText -match '[-=*#~]{4,}') {
            $findings.Add([LintFinding]@{
                    Line = $lineNumber
                    Rule = 'Never decorate with banners and ==== section ==== bars.'
                    Text = $lineText.Trim()
                })
        }
    }
}
# ast-grep skips a file that no rule's language covers, so a new rules file needs no change here.
if ($extension -notin $powerShellExtensions) {
    # herdr panes keep the PATH from when the herdr server started, which predates a winget install of ast-grep.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Get-Command ast-grep -ErrorAction SilentlyContinue)) {
        throw 'ast-grep is not on PATH. Install it with: winget install --id ast-grep.ast-grep --exact'
    }
    $sgConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ast-grep\sgconfig.yml'
    # Exit code 1 only means error-severity findings, and stderr then carries a summary line.
    [object[]]$scanOutput = & ast-grep scan --config $sgConfigPath --json=compact $filePath 2>&1
    [int]$scanExitCode = $LASTEXITCODE
    [string]$scanJson = ($scanOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    if ($scanExitCode -gt 1 -or -not $scanJson.StartsWith('[')) {
        throw "ast-grep scan of $filePath failed (exit $scanExitCode): $($scanOutput -join "`n")"
    }
    foreach ($astGrepMatch in @($scanJson | ConvertFrom-Json)) {
        $findings.Add([LintFinding]@{
                Line = $astGrepMatch.range.start.line + 1
                Rule = $astGrepMatch.message
                Text = $astGrepMatch.lines.Split("`n")[0].Trim()
            })
    }
}
else {
    $parseErrors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$parseErrors)
    [System.Management.Automation.Language.Ast[]]$syntaxNodes = @($scriptAst.FindAll({ $true }, $true))
    foreach ($node in $syntaxNodes) {
        [string]$rule = ''
        if ($node -is [System.Management.Automation.Language.TernaryExpressionAst]) {
            $rule = 'Plain if/else that assigns in each branch, never a ternary.'
        }
        elseif ($node -is [System.Management.Automation.Language.ParameterAst]) {
            if ($node.DefaultValue) {
                $rule = 'No default parameter values. Make every parameter explicit.'
            }
            elseif (-not @($node.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] })) {
                $rule = 'Strict typing everywhere. Give the parameter a type.'
            }
        }
        elseif ($node -is [System.Management.Automation.Language.CatchClauseAst]) {
            if ($node.Body.Statements.Count -eq 0) {
                $rule = 'Raise errors explicitly. Never silently ignore them.'
            }
            elseif ($node.IsCatchAll -and -not $node.Body.Find({ $args[0] -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)) {
                $rule = 'Use specific error types. Avoid catch-all handlers that hide the cause.'
            }
        }
        elseif ($node -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.VariablePath.UserPath -match $genericNamePattern) {
            $assignment = $node.Parent
            if ($assignment -is [System.Management.Automation.Language.ConvertExpressionAst]) {
                $assignment = $assignment.Parent
            }
            [bool]$isAssignedTarget = $assignment -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $assignment.Left.Extent.StartOffset -le $node.Extent.StartOffset -and
                $assignment.Left.Extent.EndOffset -ge $node.Extent.EndOffset -and
                $assignment.Parent -isnot [System.Management.Automation.Language.ForStatementAst]
            [bool]$isLoopVariable = $node.Parent -is [System.Management.Automation.Language.ForEachStatementAst] -and
                $node.Parent.Variable -eq $node
            if ($isAssignedTarget -or $isLoopVariable) {
                $rule = 'Name a variable for what it holds, never a generic word, an ad hoc abbreviation or a single letter.'
            }
        }
        if ($rule) {
            $findings.Add([LintFinding]@{
                    Line = $node.Extent.StartLineNumber
                    Rule = $rule
                    Text = $node.Extent.Text.Split("`n")[0].Trim()
                })
        }
    }
}

[LintFinding[]]$newFindings = @($findings | Where-Object { $writtenLines.Contains($_.Line) } | Sort-Object Line)
if ($newFindings.Count -eq 0) {
    exit 0
}
$findingLines = ($newFindings | ForEach-Object { "- ${filePath}:$($_.Line): ``$($_.Text)`` breaks: $($_.Rule)" }) -join "`n"
@{
    decision = 'block'
    reason   = "Lint of the lines this edit wrote, against ~/.claude/rules/code.md. Fix each one, or say in your reply why a finding is wrong:`n$findingLines"
} | ConvertTo-Json -Compress

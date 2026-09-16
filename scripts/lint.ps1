#Requires -Version 7
<#
.SYNOPSIS
Repo checks: every tracked config and script parses, every tracked markdown file follows the prose rules.

.DESCRIPTION
Dependency-free by design so the same command runs on a bare machine and on a GitHub runner. Only tracked
files are checked, so local scratch files and untracked config are ignored.
#>

param(
    [Parameter(Mandatory)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

class ProseLine {
    [int]$Number
    [string]$Text
}

function Get-TrackedFile([string]$repoRoot, [string]$pattern) {
    $relativePaths = & git -C $repoRoot ls-files -- $pattern
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files '${pattern}' failed in ${repoRoot} with exit code ${LASTEXITCODE}"
    }
    return @($relativePaths | ForEach-Object { Join-Path $repoRoot $_ })
}

function Test-JsonSyntax([string[]]$paths) {
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    # The VS Code configs are JSONC: the editor accepts comments and trailing commas, so this must too.
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
    $options.AllowTrailingCommas = $true

    $failures = @()
    foreach ($path in $paths) {
        try {
            [System.Text.Json.JsonDocument]::Parse((Get-Content $path -Raw), $options).Dispose()
        } catch {
            $failures += "${path}: $($_.Exception.Message)"
        }
    }
    return $failures
}

function Test-PowerShellSyntax([string[]]$paths) {
    $failures = @()
    foreach ($path in $paths) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors) | Out-Null
        foreach ($parseError in $parseErrors) {
            $failures += "${path}:$($parseError.Extent.StartLineNumber): $($parseError.Message)"
        }
    }
    return $failures
}

function Get-ProseLine([string]$path) {
    $proseLines = @()
    $lines = @(Get-Content $path)
    $inFence = $false
    $inFrontMatter = $false

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $text = $lines[$index]

        # Skill and agent front matter holds single-line YAML values that cannot be wrapped.
        if ($index -eq 0 -and $text.Trim() -eq '---') {
            $inFrontMatter = $true
            continue
        }
        if ($inFrontMatter) {
            if ($text.Trim() -eq '---') {
                $inFrontMatter = $false
            }
            continue
        }
        if ($text -match '^\s*(```|~~~)') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) {
            continue
        }

        $proseLine = [ProseLine]::new()
        $proseLine.Number = $index + 1
        $proseLine.Text = $text
        $proseLines += $proseLine
    }

    return $proseLines
}

function Test-LineLength([string]$path, [ProseLine[]]$proseLines, [int]$limit) {
    $failures = @()
    foreach ($proseLine in $proseLines) {
        if ($proseLine.Text.Length -gt $limit) {
            $failures += "${path}:$($proseLine.Number): $($proseLine.Text.Length) characters, limit is ${limit}"
        }
    }
    return $failures
}

function Test-Dash([string]$path, [ProseLine[]]$proseLines) {
    $failures = @()
    foreach ($proseLine in $proseLines) {
        # Matched by code point so this file stays free of the character it bans.
        if ($proseLine.Text -match "`u{2014}") {
            $failures += "${path}:$($proseLine.Number): em dash, rewrite with a comma, colon, parentheses, or two sentences"
        }
        if ($proseLine.Text -match '\s--\s|\w--\w') {
            $failures += "${path}:$($proseLine.Number): double hyphen used as a dash"
        }
    }
    return $failures
}

$failures = @()
$failures += Test-JsonSyntax (Get-TrackedFile $RepoRoot '*.json')
$failures += Test-PowerShellSyntax (Get-TrackedFile $RepoRoot '*.ps1')

foreach ($path in Get-TrackedFile $RepoRoot '*.md') {
    $proseLines = Get-ProseLine $path
    $failures += Test-LineLength $path $proseLines 120
    $failures += Test-Dash $path $proseLines
}

foreach ($failure in $failures) {
    Write-Host $failure -ForegroundColor Red
}

if ($failures.Count -gt 0) {
    throw "Lint failed: $($failures.Count) problem(s)"
}

Write-Host "Lint passed" -ForegroundColor Green

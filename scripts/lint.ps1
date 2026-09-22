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

function Get-RepoPath([System.Management.Automation.Language.ExpandableStringExpressionAst]$string, [string]$repoRoot) {
    # $repo becomes the repo root. Any other embedded expression, such as $($Layout.ToLower()), becomes a wildcard so
    # the path covers every value it can take.
    $path = $string.Value
    foreach ($nested in $string.NestedExpressions) {
        $replacement = if ($nested.Extent.Text -eq '$repo') { $repoRoot } else { '*' }
        $path = $path.Replace($nested.Extent.Text, $replacement)
    }
    return $path
}

function Get-OwnerExecPath([string]$repoRoot) {
    $script = Join-Path $repoRoot 'scripts\setup-agent-account.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
    $assignment = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$ownerExecPaths'
        }, $true)
    if (-not $assignment) {
        throw "no `$ownerExecPaths assignment in ${script}"
    }
    $strings = $assignment.Right.FindAll({
            param($node) $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
        }, $true)
    return @($strings | ForEach-Object { Get-RepoPath $_ $repoRoot })
}

function Get-LinkSource([string]$repoRoot) {
    $linkScripts = @(
        Join-Path $repoRoot 'scripts\setup-configs.ps1'
        Join-Path $repoRoot 'scripts\switch-layout.ps1'
    )
    $sources = @()
    foreach ($script in $linkScripts) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
        $links = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Link'
            }, $true)
        foreach ($link in $links) {
            $pattern = Get-RepoPath $link.CommandElements[2] $repoRoot
            $matched = @(Get-Item -Path $pattern -Force -ErrorAction Ignore)
            if ($matched.Count -eq 0) {
                throw "Link source ${pattern} in ${script}:$($link.Extent.StartLineNumber) matches no file"
            }
            $sources += $matched.FullName
        }
    }
    return $sources
}

function Get-LaunchedScript([string]$repoRoot) {
    # Scripts the profile, GlazeWM, and Zebar start by path. Zebar's dev dir is reached through its ~/.glzr link.
    $launchers = @(Join-Path $repoRoot 'powershell\Microsoft.PowerShell_profile.ps1') +
        @(Get-ChildItem (Join-Path $repoRoot 'glazewm') -Filter '*.yaml' | ForEach-Object FullName) +
        @(Get-ChildItem (Join-Path $repoRoot 'zebar\dev') -Filter '*.html' | ForEach-Object FullName)
    $references = @{
        'windows-dev[\\/]([\w\\/.-]+\.(?:ps1|ahk))' = $repoRoot
        '\.glzr[\\/]zebar[\\/]([\w\\/.-]+\.(?:ps1|ahk))' = Join-Path $repoRoot 'zebar'
    }
    $scripts = @()
    foreach ($launcher in $launchers) {
        $text = Get-Content $launcher -Raw
        foreach ($reference in $references.GetEnumerator()) {
            foreach ($match in [regex]::Matches($text, $reference.Key)) {
                $scripts += Join-Path $reference.Value ($match.Groups[1].Value -replace '/', '\')
            }
        }
    }
    return $scripts
}

function Test-OwnerExecCoverage([string]$repoRoot, [string[]]$protectedPaths, [string[]]$ownerRunPaths) {
    # Linked on purpose without a write block: the agent can already edit the code the CMake presets configure, and
    # the Notepad++ themes hold no executable content.
    $exempt = @(
        Join-Path $repoRoot 'cmake\CMakeUserPreset.json'
        Join-Path $repoRoot 'cmake\CMakeUserPresets.json'
        Join-Path $repoRoot 'notepadpp\themes'
    )
    $failures = @()
    foreach ($path in ($ownerRunPaths | Sort-Object -Unique)) {
        if ($path -in $exempt) {
            continue
        }
        $covered = $protectedPaths | Where-Object {
            $path -eq $_ -or $path.StartsWith("$_\", [StringComparison]::OrdinalIgnoreCase)
        }
        if (-not $covered) {
            $failures += "${path}: runs as the owner but is not in `$ownerExecPaths in scripts/setup-agent-account.ps1"
        }
    }
    return $failures
}

function Test-LayoutParity([string]$repoRoot) {
    # The Kinesis layout is the laptop layout on the other Win key, nothing else.
    $laptopPath = Join-Path $repoRoot 'glazewm\config_laptop.yaml'
    $kinesisPath = Join-Path $repoRoot 'glazewm\config_kinesis.yaml'
    $expected = @(Get-Content $laptopPath | ForEach-Object { $_ -replace '\blwin\+', 'rwin+' })
    $actual = @(Get-Content $kinesisPath)
    $failures = @()
    $lineCount = [Math]::Max($expected.Count, $actual.Count)
    for ($index = 0; $index -lt $lineCount; $index++) {
        if ($expected[$index] -cne $actual[$index]) {
            $failures += "${kinesisPath}:$($index + 1): differs from config_laptop.yaml beyond lwin to rwin"
        }
    }
    return $failures
}

$failures = @()
$failures += Test-JsonSyntax (Get-TrackedFile $RepoRoot '*.json')
$failures += Test-PowerShellSyntax (Get-TrackedFile $RepoRoot '*.ps1')
$failures += Test-OwnerExecCoverage $RepoRoot (Get-OwnerExecPath $RepoRoot) `
    ((Get-LinkSource $RepoRoot) + (Get-LaunchedScript $RepoRoot))
$failures += Test-LayoutParity $RepoRoot

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

# Prints the open PR and issue count as intarsia custom module JSON, one section per tooltip line, and writes the same
# searches as an intarsia menu to $MenuPath, so opening the menu only reads a file. Each section's header opens its
# GitHub search, each entry its page, the URL being the id on_select gets.

$ErrorActionPreference = 'Stop'
# The bar reads stdout as UTF-8.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$GitHubUser = 'CLBRITTON2'
$GitHubOrgs = 'org:openziti org:netfoundry'
$MenuPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'intarsia\ziti-menu.json'
# A menu holds at most 50 items: three headers, 15 under each and the two separators between them.
$PerSection = 15
# What a 560px menu fits of its 9px-wide monospace characters, the repo and number included.
$EntryLength = 56
$RepoAliases = @{ 'desktop-edge-win' = 'ZDEW'; 'ziti-tunnel-sdk-c' = 'ZET' }
$GhPath ='C:\Program Files\GitHub CLI\gh.exe'

# Disjoint (pr against issue, assigned excludes author), so their totals add up.
$ZitiSections = @(
    [pscustomobject]@{ Title = 'Pull requests'; Type = 'pullrequests'; Query = "$GitHubOrgs is:open is:pr author:$GitHubUser" }
    [pscustomobject]@{ Title = 'Issues'; Type = 'issues'; Query = "$GitHubOrgs is:open is:issue author:$GitHubUser" }
    [pscustomobject]@{ Title = 'Assigned to me'; Type = 'issues'; Query = "$GitHubOrgs is:open is:issue assignee:$GitHubUser -author:$GitHubUser" }
)

function Get-SectionSearchUrl {
    param([Parameter(Mandatory)] [pscustomobject] $Section)
    return "https://github.com/search?q=$([uri]::EscapeDataString($Section.Query))&type=$($Section.Type)"
}

# Through gh's login, which allows 30 searches a minute on the account's own quota rather than 10 shared by the IP.
function Invoke-SectionSearch {
    param([Parameter(Mandatory)] [pscustomobject] $Section, [Parameter(Mandatory)] [int] $PerPage)
    $attempts = 3
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        $output = & $GhPath api --method GET search/issues -f "q=$($Section.Query)" -F "per_page=$PerPage" 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $output | Out-String | ConvertFrom-Json
        }
        $message = ($output | Out-String).Trim()
        # A retry cannot outwait a rate limit, which resets on the minute, and only spends the next request.
        if ($message -match 'HTTP 4\d\d') {
            throw "GitHub search for '$($Section.Title)' refused: $message (query=$($Section.Query))"
        }
        if ($attempt -eq $attempts) {
            throw "GitHub search for '$($Section.Title)' failed after $attempts attempts: $message (query=$($Section.Query))"
        }
        # stderr, since stdout carries the JSON the bar reads.
        [Console]::Error.WriteLine("warning: GitHub search attempt=$attempt section=$($Section.Title) error=$message")
        Start-Sleep -Seconds 2
    }
}

# Issue titles are untrusted: control and bidi characters, which the bar refuses to draw, become U+FFFD.
function ConvertTo-DrawableText {
    param([Parameter(Mandatory)] [string] $Text)
    return $Text -replace '[\x00-\x1F\x7F-\x9F؜‎‏  ‪-‮⁦-⁩﻿]', [char]0xFFFD
}

# Cut at the last word that fits, so an entry reads as a phrase rather than ending mid-word.
function ConvertTo-ShortTitle {
    param([Parameter(Mandatory)] [string] $Title, [Parameter(Mandatory)] [int] $MaxLength)
    if ($Title.Length -le $MaxLength) {
        return $Title
    }
    $cut = $Title.Substring(0, $MaxLength)
    $space = $cut.LastIndexOf(' ')
    if ($space -gt 0) {
        $cut = $cut.Substring(0, $space)
    }
    return $cut.TrimEnd(' ', ',', '.', ':', '-') + [char]0x2026
}

function Format-Age {
    param([Parameter(Mandatory)] [DateTimeOffset] $Time)
    $age = [DateTimeOffset]::UtcNow - $Time
    if ($age.TotalHours -lt 1) {
        return "$([int][Math]::Floor($age.TotalMinutes))m ago"
    }
    if ($age.TotalDays -lt 1) {
        return "$([int][Math]::Floor($age.TotalHours))h ago"
    }
    return "$([int][Math]::Floor($age.TotalDays))d ago"
}

function Get-EntryTooltip {
    param([Parameter(Mandatory)] [pscustomobject] $Issue)
    $org = ($Issue.repository_url -split '/')[-2]
    $repo = ($Issue.repository_url -split '/')[-1]
    $details = "updated $(Format-Age -Time $Issue.updated_at) · $($Issue.comments) comments"
    if ($Issue.draft -eq $true) {
        $details += ' · draft'
    }
    return @((ConvertTo-DrawableText -Text $Issue.title), "$org/$repo #$($Issue.number)", $details) -join "`n"
}

# Written beside its final path and moved over it, so the menu never reads half a file.
function Write-Menu {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $Json)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $temporary = "$Path.tmp"
    [System.IO.File]::WriteAllText($temporary, $Json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

$lines = @()
$items = @()
$total = 0
foreach ($section in $ZitiSections) {
    $result = Invoke-SectionSearch -Section $section -PerPage $PerSection
    $total += $result.total_count
    $lines += "$($section.Title) $($result.total_count)"
    if ($items.Count -gt 0) {
        $items += [pscustomobject]@{ separator = $true }
    }
    $items +=[pscustomobject]@{ id = Get-SectionSearchUrl -Section $section; text = "$($section.Title) ($($result.total_count))"; active = $true }
    foreach ($issue in $result.items) {
        # Every search is within the two orgs, so the repo's own name, or its alias, is enough.
        $repo = ($issue.repository_url -split '/')[-1]
        if ($RepoAliases.ContainsKey($repo)) {
            $repo = $RepoAliases[$repo]
        }
        $prefix = "$repo #$($issue.number)  "
        $title = ConvertTo-ShortTitle -Title (ConvertTo-DrawableText -Text $issue.title) -MaxLength ($EntryLength - $prefix.Length)
        $items += [pscustomobject]@{ id = $issue.html_url; text = "$prefix$title"; tooltip = Get-EntryTooltip -Issue $issue }
    }
}
Write-Menu -Path $MenuPath -Json ([pscustomobject]@{ items = $items } | ConvertTo-Json -Compress -Depth 3)
[pscustomobject]@{ text = "$total"; tooltip = $lines -join "`n" } | ConvertTo-Json -Compress

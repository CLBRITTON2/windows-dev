<#
.SYNOPSIS
    Fast-forward-pull every git repo under an openziti dev root so Claude sessions start with fresh context.
.DESCRIPTION
    Enumerates immediate subdirectories that are git repos. For each, it fetches, then fast-forwards only
    when the working tree is clean and the current branch tracks its upstream. Dirty repos, detached heads,
    and repos with no upstream are skipped and reported, never modified.
.EXAMPLE
    ./update-ziti-repos.ps1
.EXAMPLE
    ./update-ziti-repos.ps1 -Root "D:\src\openziti"
#>
[CmdletBinding()]
param(
    [string]$Root = "$HOME\dev\openziti"
)

$ErrorActionPreference = 'Stop'

function Get-RepoState {
    param([string]$Path)

    $branch = git -C $Path rev-parse --abbrev-ref HEAD
    $dirty = [bool](git -C $Path status --porcelain)
    $upstream = git -C $Path rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null

    [pscustomobject]@{
        Name     = Split-Path $Path -Leaf
        Path     = $Path
        Branch   = $branch
        Dirty    = $dirty
        Upstream = $upstream
    }
}

if (-not (Test-Path $Root)) {
    throw "Root not found: $Root"
}

$repos = Get-ChildItem -Path $Root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName '.git') }

if (-not $repos) {
    Write-Warning "No git repos found under $Root"
    return
}

Write-Host ""
Write-Host "=== Updating openziti repos ($Root) ===" -ForegroundColor Cyan
Write-Host ""

$results = foreach ($repo in $repos) {
    $state = Get-RepoState -Path $repo.FullName
    $status = ''
    $color = 'Gray'

    if ($state.Dirty) {
        $status = "skipped (uncommitted changes) [$($state.Branch)]"
        $color = 'Yellow'
    }
    elseif ($state.Branch -eq 'HEAD') {
        $status = 'skipped (detached HEAD)'
        $color = 'Yellow'
    }
    elseif (-not $state.Upstream) {
        $status = "skipped (no upstream) [$($state.Branch)]"
        $color = 'Yellow'
    }
    else {
        git -C $state.Path fetch --quiet
        $pull = git -C $state.Path pull --ff-only 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $status = "FAILED ff-only [$($state.Branch)]: $($pull.Trim())"
            $color = 'Red'
        }
        elseif ($pull -match 'Already up to date') {
            $status = "up to date [$($state.Branch)]"
            $color = 'DarkGray'
        }
        else {
            $status = "pulled [$($state.Branch)]"
            $color = 'Green'
        }
    }

    Write-Host ("  {0,-24} {1}" -f $state.Name, $status) -ForegroundColor $color
    [pscustomobject]@{ Name = $state.Name; Status = $status }
}

Write-Host ""
Write-Host "=== Done ($($results.Count) repos) ===" -ForegroundColor Cyan

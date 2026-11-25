#Requires -Version 7
<#
.SYNOPSIS
Rewrites every terminus/canon/projects/<repo>/rubric.yaml to list each shared rule of the canon as blocking.

.DESCRIPTION
terminus loads only the rubric whose project.repo matches the reviewed repo, and a rubric has no include, so each repo
keeps its own full list of the shared rules. A shared rule is every *.md outside projects/, its ref the path without
the extension. A new repo gets a rubric by creating its empty projects/<repo>/ folder before the run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonRoot = Join-Path $PSScriptRoot '..\terminus\canon' | Resolve-Path
$projectsRoot = Join-Path $canonRoot 'projects'

$ruleRefs = Get-ChildItem -Path $canonRoot -Recurse -File -Filter '*.md' |
    Where-Object { -not $_.FullName.StartsWith($projectsRoot + [IO.Path]::DirectorySeparatorChar) } |
    ForEach-Object { [IO.Path]::GetRelativePath($canonRoot, $_.FullName) -replace '\\', '/' -replace '\.md$', '' } |
    Sort-Object -CaseSensitive
if (-not $ruleRefs) {
    throw "No rule files found under $canonRoot outside projects\"
}

$qualityLines = foreach ($ruleRef in $ruleRefs) {
    "  - ref: $ruleRef"
    '    blocking: true'
}

foreach ($projectDir in Get-ChildItem -Path $projectsRoot -Directory -Force) {
    $rubricLines = @('project:', "  repo: $($projectDir.Name)", '', 'qualities:') + $qualityLines
    $rubricPath = Join-Path $projectDir.FullName 'rubric.yaml'
    [IO.File]::WriteAllText($rubricPath, ($rubricLines -join "`n") + "`n")
    Write-Output "$rubricPath ($($ruleRefs.Count) rules)"
}

#Requires -Version 7
<#
.SYNOPSIS
Removes each worktree under <DevRoot>\worktrees whose branch reached origin's default branch, on the laptop and in the
agent VM.

.DESCRIPTION
Runs on the laptop. A worktree is pruned when its branch tip is a merged PR's head commit, or when the branch has
commits since it was created and each one is in origin's default branch or was cherry-picked onto it (git cherry
shows no + line), neither copy has uncommitted changes, and perusal has taken the agent copy's last commit: the agent's HEAD is perusal's taken ref for
the branch, or is already in the laptop branch. Pruning removes the agent's worktree and branch first, then the
laptop's worktree, branch and perusal's taken ref. Every other worktree stays and is listed with the reason.

.EXAMPLE
pwsh -NoProfile -File $HOME\dev\windows-dev\scripts\prune-worktrees.ps1 -DevRoot $HOME\dev -AgentHost claude-vm -AgentDevRoot C:/Users/claude/dev
#>

param(
    [Parameter(Mandatory)]
    [string]$DevRoot,
    [Parameter(Mandatory)]
    [string]$AgentHost,
    [Parameter(Mandatory)]
    [string]$AgentDevRoot
)

$ErrorActionPreference = 'Stop'

class WorktreeVerdict {
    [string]$State
    [string]$RelativePath
    [string]$Branch
    [string]$Reason
}

class AgentWorktree {
    [bool]$Exists
    [bool]$Dirty
    [string]$Head
}

function Invoke-Git([string]$repoDir, [string[]]$gitArguments) {
    $output = & git -C $repoDir @gitArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git -C $repoDir $($gitArguments -join ' ') failed with exit code ${LASTEXITCODE}: $($output -join "`n")"
    }
    return [string]($output -join "`n")
}

function Test-GitSucceeds([string]$repoDir, [string[]]$gitArguments) {
    & git -C $repoDir @gitArguments 2>&1 | Out-Null
    return [bool]($LASTEXITCODE -eq 0)
}

# The agent's sshd runs commands through pwsh, so an encoded script avoids quoting through ssh and pwsh -c.
function Invoke-AgentScript([string]$agentHost, [string]$script) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $output = & ssh $agentHost pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "ssh $agentHost failed with exit code ${LASTEXITCODE} running:`n$script`nOutput: $($output -join "`n")"
    }
    return [string]($output -join "`n")
}

# A worktree's own folders are not searched, so a submodule's .git file inside one is not taken for a worktree.
function Find-WorkTreeDir([string]$dir) {
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
        return [string[]]@($dir)
    }
    return [string[]]@(Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object { Find-WorkTreeDir $_.FullName })
}

$worktreesRoot = Join-Path $DevRoot 'worktrees'
if (!(Test-Path -LiteralPath $worktreesRoot)) {
    throw "No worktrees folder at $worktreesRoot. Pass the laptop's dev folder as -DevRoot."
}

$verdicts = foreach ($workTree in Find-WorkTreeDir $worktreesRoot) {
    $relativePath = [IO.Path]::GetRelativePath($DevRoot, $workTree)
    $verdict = [WorktreeVerdict]@{ RelativePath = $relativePath }
    $branch = & git -C $workTree symbolic-ref --quiet --short HEAD
    if ($LASTEXITCODE -ne 0) {
        $verdict.State = 'DETACHED'
        $verdict.Reason = 'HEAD is on no branch'
        $verdict
        continue
    }
    $verdict.Branch = $branch
    if (Invoke-Git $workTree @('status', '--porcelain')) {
        $verdict.State = 'DIRTY'
        $verdict.Reason = 'uncommitted changes on the laptop'
        $verdict
        continue
    }

    $head = Invoke-Git $workTree @('rev-parse', 'HEAD')
    $originUrl = Invoke-Git $workTree @('remote', 'get-url', 'origin')
    $slugMatch = [regex]::Match($originUrl, 'github\.com[:/](?<slug>[^/]+/[^/]+?)(?:\.git)?/?$')
    if (!$slugMatch.Success) {
        throw "Origin $originUrl of $workTree is not a GitHub repository"
    }
    $slug = $slugMatch.Groups['slug'].Value
    $mergedHeads = & gh pr list --repo $slug --head $branch --state merged --json headRefOid --jq '.[].headRefOid' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh pr list --repo $slug --head $branch failed with exit code ${LASTEXITCODE}: $($mergedHeads -join "`n")"
    }
    if (@($mergedHeads) -contains $head) {
        $landedReason = "merged PR head $($head.Substring(0, 8))"
    } else {
        $defaultBranch = & gh repo view $slug --json defaultBranchRef --jq '.defaultBranchRef.name' 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "gh repo view $slug failed with exit code ${LASTEXITCODE}: $($defaultBranch -join "`n")"
        }
        Invoke-Git $workTree @('fetch', 'origin', $defaultBranch) | Out-Null
        # The oldest reflog entry is where worktree add created the branch. A branch still there has no work of its own,
        # so being in the default branch says nothing about it.
        $createdAt = @((Invoke-Git $workTree @('reflog', 'show', '--format=%H', "refs/heads/$branch")) -split "`n")[-1]
        $unlandedCommits = @((Invoke-Git $workTree @('cherry', "origin/$defaultBranch", $head)) -split "`n" |
            Where-Object { $_.StartsWith('+') })
        if ($head -eq $createdAt) {
            $verdict.State = 'ACTIVE'
            $verdict.Reason = "no commits since the branch was created at $($createdAt.Substring(0, 8))"
            $verdict
            continue
        }
        if ($unlandedCommits.Count -gt 0) {
            $verdict.State = 'ACTIVE'
            $verdict.Reason = "no merged PR in $slug has head $($head.Substring(0, 8)), and " +
                "$($unlandedCommits.Count) commits are not in origin/$defaultBranch"
            $verdict
            continue
        }
        $landedReason = "every commit since $($createdAt.Substring(0, 8)) is in origin/$defaultBranch"
    }

    $commonGitDir = Invoke-Git $workTree @('rev-parse', '--path-format=absolute', '--git-common-dir')
    $cloneDir = Split-Path $commonGitDir -Parent
    $agentClone = (Join-Path $AgentDevRoot ([IO.Path]::GetRelativePath($DevRoot, $cloneDir))) -replace '\\', '/'
    $agentWorkTree = (Join-Path $AgentDevRoot $relativePath) -replace '\\', '/'
    $agentStateJson = Invoke-AgentScript $AgentHost @"
if (Test-Path -LiteralPath '$agentWorkTree') {
    `$porcelain = git -C '$agentWorkTree' status --porcelain
    if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
    `$agentHead = git -C '$agentWorkTree' rev-parse HEAD
    if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
    @{ Exists = `$true; Dirty = [bool]`$porcelain; Head = `$agentHead } | ConvertTo-Json -Compress
} else {
    @{ Exists = `$false; Dirty = `$false; Head = '' } | ConvertTo-Json -Compress
}
"@
    $agentState = [AgentWorktree]($agentStateJson | ConvertFrom-Json)
    if ($agentState.Dirty) {
        $verdict.State = 'AGENT-DIRTY'
        $verdict.Reason = "uncommitted changes in $AgentHost`:$agentWorkTree"
        $verdict
        continue
    }
    if ($agentState.Exists) {
        $takenRef = "refs/perusal/taken/heads/$branch"
        $takenCommit = & git -C $workTree rev-parse --verify --quiet $takenRef
        $isTaken = $agentState.Head -eq $takenCommit -or (
            (Test-GitSucceeds $workTree @('cat-file', '-e', "$($agentState.Head)^{commit}")) -and
            (Test-GitSucceeds $workTree @('merge-base', '--is-ancestor', $agentState.Head, $head)))
        if (!$isTaken) {
            $verdict.State = 'AGENT-UNTAKEN'
            $verdict.Reason = "perusal has not taken $AgentHost commit $($agentState.Head.Substring(0, 8))"
            $verdict
            continue
        }
        Invoke-AgentScript $AgentHost @"
git -C '$agentClone' worktree remove '$agentWorkTree'
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
git -C '$agentClone' branch -D '$branch'
exit `$LASTEXITCODE
"@ | Out-Null
    }

    Invoke-Git $cloneDir @('worktree', 'remove', $workTree) | Out-Null
    Invoke-Git $cloneDir @('branch', '-D', $branch) | Out-Null
    Invoke-Git $cloneDir @('update-ref', '-d', "refs/perusal/taken/heads/$branch") | Out-Null
    $verdict.State = 'PRUNED'
    $verdict.Reason = $landedReason
    $verdict
}

$verdicts | Format-Table -AutoSize -Wrap

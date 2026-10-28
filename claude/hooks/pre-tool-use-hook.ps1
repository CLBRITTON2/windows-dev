# Explicit UTF-8: the default console input encoding is the OEM code page, which mangles non-ASCII
# payload content such as the em dash the Write/Edit check below looks for.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$rawInput = $reader.ReadToEnd()
$json = $rawInput | ConvertFrom-Json

if ($json.tool_name -eq "Bash") {
    $cmd = $json.tool_input.command

    # Global options before the subcommand, including those whose value is a separate word ('-c x=y', '-C <path>').
    $gitOptions = '(?:(?:-[cC]|--git-dir|--work-tree|--namespace)\s+\S+\s+|-\S+\s+)*'
    # '--sort' alone does not put 'git tag' in list mode, so it counts only before a listing flag or the end.
    $tagListing = '(?:\s+(?:--sort|--format|--color|--column)=\S+)*(?:\s+(?:-l|--list|--contains|--no-contains|--points-at|--merged|--no-merged|-n\d*)\b|\s*(?:$|[;&|)\n]|\d*>))'

    # Second layer under the settings.json deny list, which misses forms like 'git -c x=y commit'.
    # Bare 'git branch' and the listing forms of 'git tag' stay allowed, so those match only when they mutate.
    if ($cmd -match "\bgit\s+$gitOptions(add|commit|push|pull|fetch|checkout|switch|rebase|reset|restore|clean|merge|tag(?!$tagListing))(?![\w-])" -or
        $cmd -match "\bgit\s+$gitOptions" + 'branch\s+(-[dDmMcC]\b|--(delete|move|copy|force|set-upstream|unset-upstream)\b)') {
        @{
            decision = "block"
            reason   = "Do not mutate the git repo. Hand the command to the user to run instead."
        } | ConvertTo-Json -Compress
        exit 0
    }

    # A cd carries into every later Bash call, so each command's meaning would depend on call history.
    if ($cmd -match '(^|;|\n|&&|\|\|)\s*cd\s') {
        @{
            decision = "block"
            reason   = "Do not cd. Pass absolute paths to every command, and read another repo with 'git -C <path>' and a read-only subcommand."
        } | ConvertTo-Json -Compress
        exit 0
    }

	# Reading another repo needs -C because cd is blocked, so only read-only subcommands may target one.
	foreach ($git in [regex]::Matches($cmd, "\bgit\s+(?<options>$gitOptions)(?<subcommand>[\w-]+)(?<rest>[^\n;&|]*)")) {
		$subcommand = $git.Groups['subcommand'].Value
		$rest = $git.Groups['rest'].Value
		$operands = @(($rest -replace '\s\d*>.*', '').Trim() -split '\s+' | Where-Object { $_ -and $_ -notlike '-*' })
		# config, remote, branch, reflog, worktree and stash also write, so only their reading forms pass.
		$readOnly = $subcommand -cmatch '^(status|log|diff|show|blame|rev-parse|rev-list|merge-base|ls-files|ls-tree|ls-remote|check-ignore|check-attr|grep|describe|shortlog|for-each-ref|cat-file)$' -or
			($subcommand -ceq 'tag' -and $rest -match "^$tagListing") -or
			($subcommand -ceq 'config' -and $rest -notmatch '\s(--unset\S*|--add|--replace-all|--rename-section|--remove-section|--edit|-e)\b' -and
				($rest -match '^\s+(get|list)\b|\s(--get\S*|--list|-l)\b' -or $operands.Count -eq 1)) -or
			($subcommand -ceq 'remote' -and $rest -notmatch '^\s+(add|remove|rm|rename|set-\S+|prune|update)\b') -or
			($subcommand -ceq 'branch' -and ($rest -match '\s(--list|-l|--show-current)\b' -or $operands.Count -eq 0)) -or
			($subcommand -ceq 'reflog' -and $rest -notmatch '^\s+(expire|delete)\b') -or
			($subcommand -ceq 'worktree' -and $rest -match '^\s+list\b') -or
			($subcommand -ceq 'stash' -and $rest -match '^\s+(list|show)\b')
		if ($git.Groups['options'].Value -cmatch '(^|\s)(-C\s|--git-dir|--work-tree)' -and -not $readOnly) {
			@{
				decision = "block"
				reason   = "'git -C <path>' and 'git --git-dir=<path>' allow only read-only subcommands (status, log, diff, show, blame, rev-parse, rev-list, merge-base, ls-files, ls-tree, ls-remote, check-ignore, check-attr, grep, describe, shortlog, for-each-ref, cat-file) and the reading forms of tag, config, remote, branch, reflog, worktree list and stash list/show."
			} | ConvertTo-Json -Compress
			exit 0
		}
	}

	# Docker: forbid inline env-var prefixes; env must be passed via flags
	if ($cmd -match '^\s*([A-Za-z_]\w*=\S+\s+)+docker\b') {
		@{
			decision = "block"
			reason   = "Do not prefix inline env vars before docker (e.g. 'FOO=bar docker ...'). Pass env explicitly: 'docker run -e VAR=val', a compose block, or '--env-file'."
		} | ConvertTo-Json -Compress
		exit 0
	}
	
	$unquoted = $cmd -replace '''[^'']*''|"(?:[^"\\]|\\.)*"', '""'

	# Bash strips unquoted backslashes, so 'C:\Users\x\out.png' becomes a junk file named 'C:Usersxout.png' in the cwd.
	if ($unquoted -match '(?<![\w/])[A-Za-z]:\\') {
		@{
			decision = "block"
			reason   = "Write Windows paths with forward slashes (C:/Users/...) or quote them. Bash strips unquoted backslashes."
		} | ConvertTo-Json -Compress
		exit 0
	}

	# The owner reviews repo changes as Edit and Write diffs, which a Bash write never shows.
	$slashed = $cmd -replace '\\', '/'
	$repoRoot = '(?:(?:[a-z]:|/[a-z])?/users/(?:chris|claude)/dev/|~/dev/|\$\{?home\}?/dev/)'
	$rootVars = @([regex]::Matches($slashed, "(?i)(?:\b(?<name>\w+)=[""']?|\bfor\s+(?<name>\w+)\s+in\s+[""']?)$repoRoot") |
		ForEach-Object { $_.Groups['name'].Value })
	if ($rootVars.Count -gt 0) {
		$derivedVars = @([regex]::Matches($slashed, "\b(?<name>\w+)=[""']?\$\{?(?:$($rootVars -join '|'))\b") |
			ForEach-Object { $_.Groups['name'].Value })
		$repoTarget = "(?:$repoRoot|\$\{?(?:$(($rootVars + $derivedVars) -join '|'))\b)"
	}
	else {
		$repoTarget = $repoRoot
	}
	# Single-quoted sed scripts are dropped so their ';' and '|' do not end the command segment early.
	$scriptless = ($cmd -replace "'[^']*'", "''") -replace '\\', '/'
	$inPlace = "\b(?:sed|perl)(?:\s+[^\n;&|]*?)?\s(?-i:-[a-z]*i|--in-place)\S*\s[^\n;&|]*$repoTarget"
	$redirect = "(?:(?<![=-])>{1,2}|\btee\s+(?:-a\s+)?)\s*[""']?$repoTarget"
	$writeCall = '\b(?:writeFileSync|appendFileSync|writeFile|appendFile|createWriteStream)\s*\(|\b(?:Set-Content|Add-Content|Out-File)\s'
	if ($scriptless -match "(?i)$inPlace" -or $slashed -match "(?i)$redirect" -or ($slashed -match "(?i)$writeCall" -and $slashed -match "(?i)$repoRoot")) {
		@{
			decision = "block"
			reason   = "Change files under ~/dev only with the Edit or Write tool, so the owner sees the diff. Bash may write only into the scratchpad: to process a repo file there, copy it into the scratchpad in its own call first."
		} | ConvertTo-Json -Compress
		exit 0
	}

	# Allow the specific PR inline-comments endpoint (the block below is too broad for this case)
	if ($cmd -match '^gh\s+api\s+-X\s+GET\s+repos/[^/\s]+/[^/\s]+/pulls/\d+/comments\b') {
		@{
			decision = "approve"
			reason   = "gh api .../pulls/<n>/comments is the correct endpoint for inline review comments."
		} | ConvertTo-Json -Compress
		exit 0
	}
	
	# gh api must ALWAYS start with gh api -X GET immediately after gh api
	if ($cmd -match '^gh\s+api\b' -and $cmd -notmatch '^gh\s+api\s+-X\s+GET\b') {
		@{
			decision = "block"
			reason   = "gh api calls must start with: gh api -X GET"
		} | ConvertTo-Json -Compress
		exit 0
	}
}

if ($json.tool_name -eq "Write" -or $json.tool_name -eq "Edit") {
    $path = ($json.tool_input.file_path -replace '\\', '/')
    $written = "$($json.tool_input.content)$($json.tool_input.new_string)"

    if ($written.Contains([char]0x2014)) {
        @{
            decision = "block"
            reason   = "Never use the em dash character (U+2014). Rewrite the sentence: split it, or use a comma, parentheses, or a colon."
        } | ConvertTo-Json -Compress
        exit 0
    }

    if ($path -match '\.(css|scss|sass|less)$' -and $written -match '!important') {
        @{
            decision = "block"
            reason   = "Never add !important to CSS rules. Rework the selector specificity instead."
        } | ConvertTo-Json -Compress
        exit 0
    }

    $leaf = ($path -split '/')[-1]
    if ($leaf -eq '.env' -or $leaf -like '.env.*') {
        @{
            decision = "block"
            reason   = "Do not write .env files, they hold secrets."
        } | ConvertTo-Json -Compress
        exit 0
    }
}

exit 0
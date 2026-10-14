# Explicit UTF-8: the default console input encoding is the OEM code page, which mangles non-ASCII
# payload content such as the em dash the Write/Edit check below looks for.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
$rawInput = $reader.ReadToEnd()
$json = $rawInput | ConvertFrom-Json

if ($json.tool_name -eq "Bash") {
    $cmd = $json.tool_input.command

    if ($cmd -match 'co-authored-by') {
        @{
            decision = "block"
            reason   = "Never add a Co-Authored-By trailer to a commit message or PR description, and never suggest one. No attribution line of any kind."
        } | ConvertTo-Json -Compress
        exit 0
    }

    # Global options before the subcommand, including those whose value is a separate word ('-c x=y', '-C <path>').
    $gitOptions = '(?:(?:-[cC]|--git-dir|--work-tree|--namespace)\s+\S+\s+|-\S+\s+)*'

    # Second layer under the settings.json deny list, which misses forms like 'git -c x=y commit'.
    # Bare 'git branch' and the listing forms of 'git tag' stay allowed, so those match only when they mutate.
    if ($cmd -match "\bgit\s+$gitOptions(add|commit|push|pull|fetch|checkout|switch|rebase|reset|restore|clean|merge(?!-base)|tag(?!\s+(-l|--list|--contains|--no-contains|--points-at|--merged|--no-merged)\b))\b" -or
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
	foreach ($git in [regex]::Matches($cmd, "\bgit\s+(?<options>$gitOptions)(?<subcommand>[\w-]+)")) {
		if ($git.Groups['options'].Value -cmatch '(^|\s)(-C\s|--git-dir|--work-tree)' -and
			$git.Groups['subcommand'].Value -cnotmatch '^(status|log|diff|show|blame|rev-parse|merge-base|ls-files|grep|describe|shortlog)$') {
			@{
				decision = "block"
				reason   = "'git -C <path>' and 'git --git-dir=<path>' allow only read-only subcommands (status, log, diff, show, blame, rev-parse, merge-base, ls-files, grep, describe, shortlog)."
			} | ConvertTo-Json -Compress
			exit 0
		}
	}

	if ($cmd -match '(^|;|\n)\s*find\s+') {
		@{
			decision = "block"
			reason   = "Do not use 'find' in bash. Use glob patterns instead."
		} | ConvertTo-Json -Compress
		exit 0
	}

	# Docker: forbid inline env-var prefixes; env must be passed via flags
	if ($cmd -match '^\s*([A-Za-z_]\w*=\S+\s+)+docker\b') {
		@{
			decision = "block"
			reason   = "Do not prefix inline env vars before docker (e.g. 'FOO=bar docker ...'). Pass env explicitly: 'docker run -e VAR=val', a compose block, or '--env-file'."
		} | ConvertTo-Json -Compress
		exit 0
	}
	
	# Quoted text is an argument (a sed script, a regex, a pwsh -Command), not chaining or redirection.
	$unquoted = $cmd -replace '''[^'']*''|"(?:[^"\\]|\\.)*"', '""'

	if ($unquoted -match ';') {
		@{
			decision = "block"
			reason   = "Do not chain multiple commands with ';'. Run one command at a time."
		} | ConvertTo-Json -Compress
		exit 0
	}
	
	# Duplicating a stream (2>&1) or discarding it (2>/dev/null) writes no file, so tee is no substitute.
	if (($unquoted -replace '\d*>&\d+|\d*>\s*/dev/null\b', '') -match '[>]{1,2}\s*\S+') {
		@{
			decision = "block"
			reason   = "Use tee instead of > or >> for output redirection."
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
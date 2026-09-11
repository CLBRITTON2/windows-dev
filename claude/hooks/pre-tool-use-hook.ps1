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

    # Second layer under the settings.json deny list, which misses forms like 'git -c x=y commit'.
    # Bare 'git branch' lists and stays allowed, so branch is matched only with a mutating flag.
    if ($cmd -match '\bgit\s+(-\S+\s+)*(add|commit|push|pull|fetch|checkout|switch|rebase|reset|restore|clean|merge|tag)\b' -or
        $cmd -match '\bgit\s+(-\S+\s+)*branch\s+(-[dDmMcC]\b|--(delete|move|copy|force|set-upstream|unset-upstream)\b)') {
        @{
            decision = "block"
            reason   = "Do not mutate the git repo. Hand the command to the user to run instead."
        } | ConvertTo-Json -Compress
        exit 0
    }

    if ($cmd -match '(^|;|\n)\s*cd\s+\S.*&&') {
        @{
            decision = "block"
            reason   = "Do not use compound 'cd /path && command' patterns. Run 'cd /path' as a standalone command first, then run subsequent commands without cd prefixes."
        } | ConvertTo-Json -Compress
        exit 0
    }

	if ($cmd -match '(^|;|\n)\s*git\s+((?:-C\s+\S+)|(?:.*--git-dir=\S+))') {
		@{
			decision = "block"
			reason   = "Do not use 'git -C <path>' or 'git --git-dir=<path>' patterns. Run 'cd /path' as a standalone command first, then run the git command normally."
		} | ConvertTo-Json -Compress
		exit 0
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
	
	if ($cmd -match ';') {
		@{
			decision = "block"
			reason   = "Do not chain multiple commands with ';'. Run one command at a time."
		} | ConvertTo-Json -Compress
		exit 0
	}
	
	if ($cmd -match '[>]{1,2}\s*\S+') {
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
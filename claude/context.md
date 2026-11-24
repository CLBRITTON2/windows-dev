# Working rules

Context loaded at the start of every Claude Code session: `~/.claude/CLAUDE.md` is a symlink to this file.
This repo is the source of truth. Code, comment, and error handling rules live in `rules/code.md`, which also loads at
the start of every session, and in the terminus canon it points to. The agent VM workflow (git, worktrees, perusal,
terminus reviews, scratch files, context upkeep) lives in `~/dev/agents/CLAUDE.md`, where every session starts.

## Writing

- English only, in prose and code.
- In text a maintainer reads (issues, PR bodies, chat drafts, comments), name the code's own identifier, not a
  paraphrase. Before using a precise term (clamp, floor, race, leak), confirm the code does exactly that.
- When writing markdown to a file, wrap prose at 120 characters per line. Files only, never chat replies.

## Workflow

- In-repo edits in my projects: proceed. Reversible actions (build, run tests, write a file): proceed.
- Hard to reverse or outward facing (hits a remote, deletes, touches CI/CD or production): ask first.
- Keep changes minimal and related to the request. Do not revert unrelated changes.
- If a dependency is installed locally, read its source instead of guessing.
- Clean up after yourself before finishing a task, without asking: delete what the task left outside the scratchpad
  (exes renamed aside to install over a running one, test installs, stray test files) and stop the processes and
  test sessions it started.
- Diagnosing a failure or explaining how code behaves at runtime: quote the log line, source line, or command output
  before naming a cause or a flow. A claim with none behind it is labeled a hypothesis.
- When project instructions include test or lint commands, run them before finishing if the task changed
  code.

## Shell

- Primary shell is PowerShell. Use PowerShell syntax when targeting it: `$null`, `$env:VAR`, backtick for
  line continuation. Bash is for one-offs and POSIX scripts.
- Prefer `rg` for searching code and files. Prefer non-interactive flags over interactive prompts.
- Every path in a command handed to me is absolute (scripts, configs, logs, build outputs), so it runs from any
  directory.
- The Bash tool is Git Bash. Write Windows paths with forward slashes (`C:/Users/...`) or quoted, since Bash strips
  unquoted backslashes. Start every `gh api` call with `gh api -X GET`. Run a PowerShell script with
  `pwsh -NoProfile -File <script>`, never `-ExecutionPolicy Bypass`.

## GitHub Actions

- Put all logic in a script (PowerShell, bash) that runs locally. The workflow only checks out code and
  invokes the script. Pass GitHub-specific values (tokens, run IDs) as script parameters so they can be
  supplied manually when running locally.

## Security

- Never read `.env`, `.env.*`, `secrets/`, `~/.aws/`, `~/.encrypted/`, `~/.ssh/`, the E: drive, or credential
  stores.
- No silent fallbacks that mask an auth or validation failure. Never leak secrets into logs.

## Environment

- `ziti` is on my PATH but not the agent's: download the release a task needs into the session scratchpad.
- Match the toolchain already present in a repo. Do not introduce a new build system.

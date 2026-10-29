# Working rules

Context loaded at the start of every Claude Code session: `~/.claude/CLAUDE.md` is a symlink to this file.
This repo is the source of truth. Code, comment, and error handling rules live in `rules/code.md`, which loads when
a code file is touched.

## Writing

- English only, in prose and code.
- In text a maintainer reads (issues, PR bodies, chat drafts, comments), name the code's own identifier, not a
  paraphrase. Before using a precise term (clamp, floor, race, leak), confirm the code does exactly that.
- When writing markdown to a file, wrap prose at 120 characters per line. Files only, never chat replies.

## Workflow

- Read existing code and relevant `CLAUDE.md` files before editing.
- In-repo edits in my projects: proceed. Reversible actions (build, run tests, write a file): proceed.
- Hard to reverse or outward facing (hits a remote, deletes, touches CI/CD or production): ask first.
- Keep changes minimal and related to the request. Do not revert unrelated changes.
- If unsure, inspect the codebase instead of inventing patterns.
- Test data, repro artifacts, and downloads go in the session scratchpad, nowhere else in the agent's home. The one
  persistent sandbox is `~\VMs`. `scripts/clean-agent.ps1` in windows-dev deletes the scratch folders of sessions
  idle for 7 days, so anything worth keeping goes into the agents repo context file first.
- Diagnosing a failure or explaining how code behaves at runtime: quote the log line, source line, or command output
  before naming a cause or a flow. A claim with none behind it is labeled a hypothesis.
- When project instructions include test or lint commands, run them before finishing if the task changed
  code.

## Git

- I run all git mutations myself. Never run a mutating git command (add, commit, branch, push, pull, fetch,
  checkout, reset, rebase, restore, clean, merge, tag) and never ask permission to run one. Hand over git
  commands or a commit message only when I ask for one.
- Run `git status` and `git log` right before handing me git commands, and build them from what is actually
  uncommitted. Never guess whether I already committed an earlier change.
- Run `git status` in the same turn before saying anything about what is committed or pending, including "next is
  the commit" or "still uncommitted". I commit between turns without saying so.
- Reading is fine: run `git --no-pager diff`, `git log`, `git show`, or `git status` to inspect when you
  need to.

## Shell

- Primary shell is PowerShell. Use PowerShell syntax when targeting it: `$null`, `$env:VAR`, backtick for
  line continuation. Bash is for one-offs and POSIX scripts.
- Prefer `rg` for searching code and files. Prefer non-interactive flags over interactive prompts.
- Every path in a command handed to me is absolute (scripts, configs, logs, build outputs), so it runs from any
  directory.
- The Bash tool is Git Bash. Never `cd`: pass absolute paths, and read another repo with `git -C <path>`. Write
  Windows paths with forward slashes (`C:/Users/...`) or quoted, since Bash strips unquoted backslashes. Start every
  `gh api` call with `gh api -X GET`. Run a PowerShell script with `pwsh -NoProfile -File <script>`, never
  `-ExecutionPolicy Bypass`.

## Dependencies

- Install into the project environment, not globally. Add dependencies to project config files
  (package.json, pyproject.toml, go.mod), not as one-off manual installs.
- If a dependency is installed locally, read its source instead of guessing.

## GitHub Actions

- Put all logic in a script (PowerShell, bash) that runs locally. The workflow only checks out code and
  invokes the script. Pass GitHub-specific values (tokens, run IDs) as script parameters so they can be
  supplied manually when running locally.

## Knowledge upkeep

- Project `CLAUDE.md` files may be symlinks. Edit the symlink target, never through the link.
- When a session settles what a term means, finds a version-specific behavior, or corrects a wrong
  assumption about a subsystem, fold it into that project's `CLAUDE.md` in the same turn without being
  asked (terms go in its `## Vocabulary` section). Current state only, no changelog.
- Durable findings about a project go in its context file in the agents repo, never in auto-memory or ad hoc
  files. Leave it uncommitted: I commit the agents repo myself.

## Security

- Never read `.env`, `.env.*`, `secrets/`, `~/.aws/`, `~/.encrypted/`, `~/.ssh/`, the E: drive, or credential
  stores.
- No silent fallbacks that mask an auth or validation failure. Never leak secrets into logs.

## Environment

- WSL (zsh) for POSIX work.
- Build mostly in Go, CMake, and node (npm and yarn). I work in the openziti and netfoundry ecosystems,
  `ziti` CLI is on my path.
- Match the toolchain already present in a repo. Do not introduce a new build system.

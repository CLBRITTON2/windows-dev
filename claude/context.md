# Working rules

Context loaded at the start of every Claude Code session via an @-import in `~/.claude/CLAUDE.md`. This
repo is the source of truth. The rules marked absolute do not bend.

## Writing

- Never use the em dash character (U+2014) anywhere: not in files, chat, commit messages, or PR
  descriptions. Never use a double hyphen as a dash. Never use a semicolon in prose. Rewrite instead: split
  the sentence, or use a comma, parentheses, or a colon. Absolute.
- English only, in prose and code.
- When writing markdown to a file, wrap prose at 120 characters per line. Files only, never chat replies.

## Code style

- Strict typing everywhere: function returns, variables, collections. Avoid `any`, `unknown`, `var`,
  `List[Dict[str, Any]]`.
- Prefer structured data models over loose dictionaries. Create proper type definitions for complex
  structures.
- No default parameter values. Make every parameter explicit.
- Write pure functions: modify return values, never input parameters or global state.
- Single purpose per function. No multi-mode behavior, no flag parameters that switch logic.
- Keep OOP simple and readable with limited inheritance.
- All imports at the top of the file.
- Follow DRY, KISS, YAGNI. Check whether the logic already exists before writing new code.
- Never add `!important` to css rules.

## Comments and docs

- A comment earns its place only by saying something the code cannot. If a reader gets it from the code,
  delete it. English only, terse, one line where you can.
- Write a comment for: the purpose of a block whose effect is not visible in the code, a non-obvious
  constraint (ideally on the same line as the purpose), a gotcha or landmine, why arbitrary-looking code has
  to be this way (the reason, not the mechanism), or a pointer (issue number, URL, spec section, upstream
  bug).
- Never write a comment that narrates the line, restates a well-named identifier (rename it instead), reads
  as changelog prose ("added this so builds are faster" is a commit message, not a comment), or decorates
  with banners and `==== section ====` bars.
- Comment the surprising line, not every line. A comment on every line means none of them is worth reading.
- The test before writing one: can the reader see it from the code? If yes, write nothing. Will it still be
  true and useful in a year to someone with no memory of this edit? If it only makes sense as a note about
  the change, it is a commit message.
- Documentation lives in the docstring of the function or class it describes. Separate docs files only when
  a concept cannot be expressed in code. Never duplicate documentation across files.
- Store knowledge as current state, not a changelog of modifications. Git history is the changelog.

## Error handling

- Raise errors explicitly. Never silently ignore them.
- Use specific error types that indicate what went wrong. Avoid catch-all handlers that hide the cause.
- Error messages must be clear, actionable, and carry enough context to debug: request params, response
  body, status codes.
- No fallbacks unless I explicitly ask for them.
- External API or service calls: retry with warnings, then raise the last error.
- Logging uses structured fields, not dynamic values interpolated into the message string.

## Workflow

- Read existing code and relevant `CLAUDE.md` files before editing.
- In-repo edits in my projects: proceed. Reversible actions (build, run tests, write a file): proceed.
- Hard to reverse or outward facing (hits a remote, deletes, touches CI/CD or production): ask first.
- Fix root causes, not symptoms. Ship a workaround only if you say so explicitly and name the real fix.
- Keep changes minimal and related to the request. Do not revert unrelated changes.
- If unsure, inspect the codebase instead of inventing patterns.
- Prove it by running it. "I ran it and got X" is done. "It should work" is not.
- When project instructions include test or lint commands, run them before finishing if the task changed
  code.

## Git

- I run all git mutations myself. Never run a mutating git command (add, commit, branch, push, pull, fetch,
  checkout, reset, rebase, restore, clean, merge, tag) and never ask permission to run one. Hand me the
  command or a one-line commit message to use, then stop.
- Reading is fine: run `git --no-pager diff`, `git log`, `git show`, or `git status` to inspect when you
  need to.
- Never add a `Co-Authored-By:` trailer to commit messages or PR descriptions, and never suggest one. No
  attribution or co-author line of any kind, ever. Absolute.

## Shell

- Primary shell is PowerShell. Use PowerShell syntax when targeting it: `$null`, `$env:VAR`, backtick for
  line continuation. Bash is for one-offs and POSIX scripts.
- Bash constraints are enforced by `agents/hooks/pre-tool-use-hook.ps1` (PreToolUse hook), so they are not
  restated here. Prefer `tee` over redirection and `rg` over `find` to avoid the hook rejecting the call.
- Prefer `rg` for searching code and files. Prefer non-interactive flags over interactive prompts.
- When handing me multiple shell commands to run in sequence, output ONLY a single fenced code block with
  the commands back-to-back. No prose between commands. Put any explanation as a `# ...` comment on the line
  above. Prose belongs before or after the block, never interleaved.

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

## Security

- Never read `.env`, `.env.*`, `secrets/`, `~/.aws/`, `~/.encrypted/`, or credential stores.
- No silent fallbacks that mask an auth or validation failure. Never leak secrets into logs.

## Environment

- Windows 11 Pro. Primary shell PowerShell. WSL (zsh) for POSIX work.
- Build mostly in Go, CMake, and node (npm and yarn). I work in the openziti and netfoundry ecosystems,
  `ziti` CLI is on my path.
- Match the toolchain already present in a repo. Do not introduce a new build system.

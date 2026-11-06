---
name: reflection
description: >
  Weekly reflection over the newest Claude Code sessions in this machine: find the friction that recurs (user
  corrections, blocked and failed tool calls, missing context, wasted calls), propose one fix per pattern in the file
  that owns it, and track which tools a fresh agent VM needs. Args: the session count, 10 when none is given.
disable-model-invocation: true
---

Type `~` paths literally and unquoted so bash expands them.

## Collect

Run `pwsh -NoProfile -File ~/.claude/skills/reflection/collect-sessions.ps1 -SessionCount <count>` with its output
redirected to `sessions.md` in the session scratchpad, then read that file in parts. Per session it lists the tool and
executable counts, the commands that were not installed, every user prompt and every failed tool call. A session whose
excerpt is not enough to judge a pattern can be searched in its transcript under `~/.claude/projects`, never read whole.

## Find patterns

A pattern qualifies when it shows in two or more sessions, or once as a user correction of a habit that will come
back. Name its kind:

- User correction: a prompt that says the agent did the wrong thing, or repeats a rule it already gave.
- Blocked call: a hook block, an auto mode classifier denial, a permission denial. Either the habit is wrong (a rule
  fixes it) or the block is (the hook or `claude/settings.json` fixes it).
- Failed call: a wrong path, flag or tool for this machine, the same command retried with small changes.
- Missing context: a long search for something a context file could state (layout, build or test command, versions).
- Tool economy: many calls for what one command or script in the repo would do.
- No-op: calls whose result the session never used.

Skip one-off slips, anything already fixed in the file that owns it, and anything the user settled differently later
in the same sessions.

## Fresh VM tools

`~/dev/agents/context/windows-dev/vm-tools.md` is the ledger of tools that sessions in the agent VM needed and neither
`~/dev/windows-dev/scripts/agent-vm-bootstrap.ps1` nor the personal setup `agent-vm-personal-setup.ps1` beside it installs.
Create it when missing, with the header the other files there use. Each entry: the tool, what needed it, and the
session id prefixes and dates it was seen in.

- Record a tool from the "Missing commands" lines, and from any executable used in two or more sessions that
  `Get-Command` resolves to something neither script installs (installed by hand in this VM, so a rebuild loses it).
- Propose promoting a tool into the personal setup when it was missing or hand-installed in sessions of two different
  weeks, or a repo's documented build or test needs it. A tool used once, or one with a workaround as short as the
  command itself, stays in the ledger. Only a tool any agent VM needs goes into the bootstrap.
- Drop an entry once either script installs it.

## Report

At most ten findings, worst first: the pattern in one line, the evidence (session id prefix plus the quoted prompt or
error), and the fix as the exact file plus the change in one line. Tool promotions count as findings. Then stop: apply
a fix only after the user picks it, one at a time. The ledger is the one file this skill edits without asking. Context
files under `~/dev/agents` stay uncommitted, edited at the symlink target.

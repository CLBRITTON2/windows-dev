---
name: lessons-learned
description: >
  Close out the session: distill what it settled about the projects touched into their context files
  (the per-project CLAUDE.md under ~/dev/agents/context), then commit the agents repo with a subject
  written from the diff. Never pushes. No args.
---

Type `~` paths literally and unquoted so bash expands them.

## Distill

List every checkout under `~/dev` this session edited, debugged, or read to answer a question. For each,
decide what it settled that a future session could not get from the code or git history:

- A term whose meaning this session pinned down. Goes under the file's `## Vocabulary` section, one line per
  term, created if missing.
- A version-specific behavior, a landmine, a contract between repos, or a build or test step that only works
  a certain way.
- An assumption that turned out wrong, recorded as the correct fact, not as the correction.

Not durable, never written: what the session did, files it changed, hypotheses it did not confirm,
anything a reader gets from the source, and anything already in the file. Sessions that settled nothing
write nothing and stop after saying so in one line.

## Write

The context file is `~/dev/<path>/CLAUDE.md`, a symlink into `~/dev/agents/context/<path>/CLAUDE.md`. Read and
edit the target under `~/dev/agents/context` directly, never the symlink: the PreToolUse hook refuses writes
through a link, and Edit requires the target itself to have been read first. A subdirectory file owns its scope,
the root file owns the rest, and each fact lives in exactly one file. A root file may list detail files (sibling
`*.md` in the same context dir, read on demand, each with its own read-when trigger) under `## Detail files`: a
fact that belongs to one of those topics goes there, not into the root. Keep the file's voice, section order, and
vocabulary. Current state only, no changelog phrasing, no dates. Prose rules: no em dash, no double hyphen as a
dash, no semicolon, wrap at 120 columns. Leave the Verified line alone.

A checkout with no context file gets one at `~/dev/agents/context/<path>/CLAUDE.md`, opened with the same
`Verified against <owner/repo> <short sha> (<date>)` header the other files use, sha read from
`.git/HEAD` and its ref. The symlink needs the owner's `install.ps1`, so name that as a follow-up.

## Commit

Run `pwsh -NoProfile -File ~/dev/agents/scripts/commit-context.ps1` once. Never run git add, commit, or
push directly, and never finish the job by hand when the script throws.

Report at most three lines: the files edited, the committed subject or `nothing to commit`, or the thrown
error verbatim.

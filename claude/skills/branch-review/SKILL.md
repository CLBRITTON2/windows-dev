---
name: branch-review
description: >
  Full review pass over the current branch diff: prune the diff's comments, then run the strict reviewer. Drafts
  an issue only in the narrow case where the review finds a bug in released code the branch touches. Reports a
  verdict, changes no git state. Args: the base branch if it is not the default.
---

Review the current branch diff and report a verdict. Never run a git mutation.

## 1. Comments

Invoke the `comment-audit` skill on the branch diff. Run it first: it edits only comments, so the review in
step 2 reports line numbers that are still valid, and has nothing left to flag about comment noise.

Carry its rename suggestions into step 2 rather than acting on them. A rename is a code change and belongs in
the review's verdict.

## 2. Review

Spawn the `pr-review` agent. It reads the diff in its own context and reports without fixing.

Relay its findings intact, grouped as it grouped them. Do not soften, re-rank, or drop a finding because it is
inconvenient. If it reports nothing, say that plainly.

## 3. Bugs

Most reviews end at step 2. A real bug is fixed on this branch with a failing test to prove it, and that is the
default for every bug-class finding. Taste, DRY, and performance findings stay review comments and are never
routed here.

Reach for the `distill-bug` skill only when both hold, and say nothing about it otherwise:

- The bug is in code this branch touches: a changed file, or the path the change calls into or is called from.
  A defect found while wandering the repo does not qualify, however real.
- It already exists in a released version, so there is a tag for `distill-bug` to re-verify the claim against
  and an issue number worth pointing a follow-up at.

## Finish

Report in this order: comment edits applied, review findings, the issue draft if there is one. End there. The
verdict is the deliverable.

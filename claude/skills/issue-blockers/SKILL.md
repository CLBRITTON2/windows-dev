---
name: issue-blockers
description: >
  Check whether work on a GitHub issue can continue. Reads the issue and its cross-referenced PRs, finds
  the local checkout, refreshes stale checkouts with the user's repo update script, verifies whether the
  blocking change actually landed, and reports one verdict per issue: BLOCKED, UNBLOCKED, or RESOLVED.
  Args: one or more issue URLs or owner/repo#N refs.
---

Answer one question per issue: can work continue, and if not, what exactly is it waiting on.

## Paths

Type `~` paths literally and unquoted so bash expands them.

- Local checkouts: `~/dev/openziti/<repo>`, one immediate subdirectory per repo, named after the repo.
- Update script: `~/dev/windows-dev/scripts/update-ziti-repos.ps1`, fast-forwards every clean checkout
  under that root.

## Gather

For each issue ref (`https://github.com/OWNER/REPO/issues/N` or `OWNER/REPO#N`):

- `gh issue view N --repo OWNER/REPO --json state,title,body,labels,comments`
- `gh api -X GET repos/OWNER/REPO/issues/N/timeline` for cross-referenced PRs, commits, and close events.

Name the blocker in one clause: a PR that must merge, a fix that must ship in a release, a maintainer
reply, or information someone owes. Every open issue waits on someone. When no PR, release, or question is
pending, the blocker is whoever owes the next action: a filed issue nobody has engaged with waits on
maintainer triage and is BLOCKED since the filing date, never UNBLOCKED.

## Local checkout

The checkout is `~/dev/openziti/<repo>`. A missing checkout is not fatal: note it and verdict from GitHub
state alone.

Check staleness without mutating: compare `git ls-remote origin <default-branch>` against the local
`origin/<default-branch>` ref. When they differ, run
`pwsh -NoProfile -File ~/dev/windows-dev/scripts/update-ziti-repos.ps1` once
per invocation (never once per issue), then re-check. The script skips dirty and non-tracking checkouts.
When it skipped the checkout that matters, say so in the report instead of pretending it is fresh.

The update script is the only permitted mutation. Never run fetch, pull, or checkout directly.

## Verify

Verdicts rest on evidence read this session, not on GitHub metadata alone:

- Blocker is a PR: merged or not. If merged, confirm the merge commit is an ancestor of local HEAD
  (`git merge-base --is-ancestor <sha> HEAD` inside the checkout) and read the changed code to confirm it
  addresses the issue rather than merely touching the same file.
- Issue closed: find the closing PR or commit from the timeline and verify it the same way.
- Waiting on a reply: check for comments newer than the user's last comment and whether they actually
  answer the open question.
- Empty timeline and no replies: hunt for a silent fix before settling on BLOCKED. Fixes land without
  anyone linking or closing the issue. In the freshly updated checkout, `git log --since=<filing date>`
  scoped to the files or subsystem the issue names, and read any hit's diff. For a bug, also check whether
  the reported behavior still exists in current source. For a feature request, check whether the feature
  now exists. A verified silent fix is RESOLVED even though the issue is still open.

With more than 3 issues, run the staleness check and update script first, then fan out one agent per issue
in a single message. Constrain each agent's return to the verdict line plus evidence bullets, never a full
report.

## Report

Before writing any verdict, check: the issue and timeline were fetched this session, the checkout state is
known (fresh, updated, skipped by the script, or absent), and the deciding evidence is in hand as a sha, a
comment, or a code fact that the bullets below will cite.

First line per issue is exactly one of these, nothing before it:

- `RESOLVED OWNER/REPO#N: <what landed>`. The fix is merged and verified present in the local checkout, or
  the issue closed with a verified fix. Nothing left to do. When the issue is still open upstream, cite
  the commit and name closing the issue as the user's next step.
- `UNBLOCKED OWNER/REPO#N: <next action>`. A specific event put the ball in the user's court: a fix merged
  to build on, an answering or approving reply, a requested change. Cite that event and the exact next
  step. Absence of a blocker is not UNBLOCKED, it means nobody has engaged yet, which is BLOCKED.
- `BLOCKED OWNER/REPO#N: <what it waits on>`. Still waiting. Name who or what, and since when.

Then at most 3 evidence bullets per issue: PR merge state with sha, checkout freshness, the decisive
comment or code fact.

## Never

- Never post a comment, edit, label, close, or react to the issue.
- Never mark UNBLOCKED or RESOLVED without evidence read this session.
- Never fix the issue. The deliverable is the verdict.

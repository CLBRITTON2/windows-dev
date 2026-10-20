---
name: slop-review
description: >
  Interactive self/slop-review of the current branch: find what should not ship, then walk the user through it chunk
  by chunk, one change site per message, and apply each change only after its own approval. Changes no git state. Use
  when the user asks for a chunk by chunk review, a self review, a slop review, or a review pass of their branch.
  Args: the base branch if it is not origin's default branch.
---

Strip what should not ship from the branch. The user sees only judgment calls, one at a time. Never run a git
mutation.

## 1. Base

- Base is the merge-base of HEAD with the base branch. Diff the working tree against it. Never diff against HEAD
  alone: that hides what the branch costs against the base.
- Every line changed against the base has a cost, including rewording, recasing and reordering untouched code.

## 2. Find

Spawn the `diff-reviewer` agent for candidates, then read the full diff yourself for what it does not weigh:

- SCOPE: a fix spread to paths that never failed. Each touched site needs the failing test or run that proves it.
- CHURN: lines changed against the base with no correctness or hygiene value. Restoring the base's text is the fix.
  Formatter churn and code moved to where it belongs are not churn, and churn never outranks correctness.
- HYGIENE: a helper with one user in a shared header or module. Ask when it could plausibly serve other callers.

Tag every finding with one category (SCOPE, DEAD, DRY, CHURN, HYGIENE, TEST, COMMENT, SIMPLIFY, CODE). While finding:

- Rank shapes: DRY and simple, then more lines but simple, then DRY but dense. A DRY fix that reads worse is not one.
- Measure a proposal's line count against the base, never guess it. Fewer lines is not a reason by itself.
- Before proposing a helper, search for an existing one and say what you searched.
- Follow the project's patterns: its `CLAUDE.md` and contributing guides, then the code on the base. A
  code-alignment question the base answers is not a question.
- A fix for a bug that also exists on the base may stay. Say that it does.
- Do not narrow a general-purpose helper to fit its current callers.

## 3. Triage

- Never edit a repo file before the user approves that change, however small. Drafts live in the scratchpad.
- Code an approved change leaves with no callers: a one-line FYI, no page or approval of its own.
- Split the diff into chunks by area (app code, CI and scripts, each source or test folder, docs) and walk them in
  order. Within a chunk, order by dependency: a new helper before its callers, code before the edits to existing
  comments that describe it. A new comment that ships with new code sits in the same diff.
- Drop a finding with no concrete gain (a cosmetic move, a rename nobody asked for) instead of presenting it.

First message: the base sha, `--stat`, the chunk list, then the first change site of the first chunk.

## 4. Present

One change site per message, then stop. A finding that touches two files is two messages.

- Fit about 35 lines. Page a bigger diff with one approval after the last page. A message that cannot fit opens with
  a plain `=== SCROLL BACK TO HERE ===` line.
- For a large or unfamiliar change, explain the mechanism first: why the code exists, what it does, why it goes.
  The user cannot judge a removal they do not understand.
- Show the real diff: patch a copy in the scratchpad and show `git --no-pager diff --no-index <file> <copy>` in a
  diff block, every line, no `...` elisions. Add a view against the base only when the first one hides the point.
- Proposed code is exactly what goes in the file. Notes go in prose, never inside the snippet.
- One or two plain lines for trade-offs, side edits, and whether a touched comment is new or exists on the base.
- End every message and every page with the fenced footer, the question folded into the SUMMARY line, no finding IDs
  or counts the user can read off the diff. A page that is not the last asks "Next?".

```
CHANGE DRY  : ctx_guard and e2ee_guard are each defined twice
SUMMARY     : Keep one copy only. Apply?
```

A judgment call shows the code it asks about above the same shape, one question per message, never answered for the
user:

```
SUMMARY HYGIENE : tls_with_ca is defined in a shared header but has one caller
QUESTION        : could other tests use a tls context built from a provided ca?
```

## 5. Decide

- "yes" approves only the last thing shown. "Apply the rest" covers only the kind just approved. Ask when the scope
  is unclear.
- An answered question is the approval: apply and show the diff as done, without asking again.
- Approved but criticized: iterate on the weak part, then apply once.
- Conditional approval: meet the condition, then say in one message that it was met and the change applied.
- Asked "why": one sentence first, detail only on request.
- Told to match a reference (another repo's tests, upstream): mirror what it does. Do not redesign or extend it.
- A claim about behavior (what a command deletes, what a probe returns) needs a command output or a source line behind
  it. Run the check before answering, or label the claim a hypothesis.
- Propose the smallest change that answers the finding. Offer more only when asked.
- Record a withdrawn finding with its reason for the final report.
- Build the touched project after each applied change, per its `CLAUDE.md`.

## 6. Finish

Run the project's test commands. Report what was applied, what was withdrawn and why, and any verification not run.
Hand over no git commands or commit message unless the user asks for one.

---
name: issue-precheck
description: Verify a bug claim against GitHub history before filing or asserting it is new. Searches issues and
  PRs (open and closed) across the involved repos for prior reports and fixes, reads the hits, and returns a
  verdict per claim, already reported, fixed in a version, or unreported. Use before drafting any issue and before
  telling anyone a bug is unreported.
---

# issue-precheck

Checks whether a bug claim already exists in GitHub history, in any state, before it gets filed or repeated.

## Process

1. Extract the searchable facts from the claim: component, feature name, symptom phrasing, exact error strings,
   function and file names, config or flag names. Each is a separate search vocabulary, do not stop at one.
2. Pick the repos: the blamed repo plus every layer the mechanism crosses (client, SDK, server). When unsure,
   add the repo, a wasted search is cheap.
3. Search issues AND PRs, always with state all:
   `gh issue list --repo <r> --state all --limit 100 --search "<term>"` and the same via `gh pr list`.
   Repeat per vocabulary from step 1. Short generic terms (the feature noun alone) beat long sentences.
4. Read every plausible hit, body and comments, not just titles. Classify: exact match, same area but different
   defect, or unrelated. An issue can be half-fixed, check whether the fix covers this claim's path.
5. For closed hits and fix PRs, list the changed files (`gh pr view <n> --json files`) and check whether the
   blamed file or path was ever touched. A fix that never touched the blamed code did not fix this claim.
6. Verdict per claim, one of: REPORTED (issue link, state, which part is still open), FIXED (PR and version, so
   the claim is stale, say what to upgrade), or UNREPORTED (searched terms listed, nothing matched).
7. When the verdict is REPORTED, the recommendation is a comment on the existing issue carrying the new
   evidence, not a new issue. When UNREPORTED, hand off to distill-bug for the filing pass.

## Rules

- Read-only gh only. Never create, edit, or comment via gh, hand the user the link and the drafted comment.
- Never call a bug unreported from a single search term or from open issues only.
- Bound the result: list the repos and terms searched so "nothing found" is a checkable statement.

## Output shape

| Claim | Verdict | Where | Still open |
|---|---|---|---|

One row per claim. Where is the issue or PR link, empty for UNREPORTED. Then the searched repos and terms as one
line each, then the recommended next step in one sentence.

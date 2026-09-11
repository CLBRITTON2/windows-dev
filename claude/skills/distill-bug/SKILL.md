---
name: distill-bug
description: Turn this session's findings into a short, verified bug report ready to file. Re-checks every code claim against source at the named version, separates verified from inferred, ends with a draft issue. Use before posting an investigation as a GitHub issue or Slack message.
---

# distill-bug

Outbound twin of humanize-issue: turns this session's investigation into a report the reader can act on without
re-deriving anything.

## Process

1. Re-verify every claim against real source at the tagged version the bug targets: a checkout at the tag, or the
   repo host at the tag. Never the Go module cache, never memory. A claim that cannot be re-verified is labeled
   unverified inline, never silently kept.
2. Two-state check: a claim about a field, flag, or message is verified only when both states are traced, what
   the sender emits for true AND for false/absent, and what the receiver does with each. Quoting a line (an
   omitempty tag, a zero-init, a default arg) is not verifying its behavior. Search every naming variant of the
   value, case-insensitively (isTotpEnrolled vs IsTotpEnrolled).
3. Blame check: the blamed code must exist in the oldest version where the symptom was observed, else the blame
   is wrong or partial.
4. Sort findings by severity. Each one: a one-sentence claim, file:line evidence, impact. Plain names, no
   invented labels or numbering schemes.
5. Label every statement: verified against source, reproduced by running, or inferred. An inference never reads
   as fact.
6. List what was not checked. A bounded claim beats an implied-complete one.
7. Flag security-sensitive findings (remote crash, credential or data leak) first and ask about an advisory flow
   before drafting anything public.
8. Propose a fix only after checking it against every caller or population that reaches the changed decision
   point. Otherwise name the defect and stop.
9. Refute pass, only when a fix is proposed: spawn a fresh subagent with the drafted findings and repo access,
   instructed to kill the fix and the claims it rests on. Rework anything it wounds.
10. Run the issue-precheck skill on the surviving claims. A REPORTED verdict turns the draft into a comment on
    the existing issue, a FIXED verdict ends the report with the version to upgrade to. Draft a new issue only
    on UNREPORTED.
11. Draft an issue: title, plain-prose body, repro block, affected versions. No Summary/Steps/Expected
    scaffolding unless the repo's template requires it. Lead with the user-visible failure in one sentence, give
    the mechanism one paragraph, and delete any sentence that restates a citation.

## Output shape

For the user's eyes only, never pasted into GitHub: one line of context, two tables, "Not checked" bullets, then
the draft issue. No other headings, no prose between tables.

| Claim | Evidence | Status | Impact |
|---|---|---|---|

One row per finding. Claim and impact under ten words each. Evidence as file:line at a named version. Status is
verified / reproduced / inferred.

| Component | Version | State |
|---|---|---|

One row per involved component. State is affected / fixed / not checked.

Voice: first person, short declaratives, no hedging adverbs, no "comprehensive/deep-dive/critical", never
restate a table row in prose. The draft issue body is prose, no tables.

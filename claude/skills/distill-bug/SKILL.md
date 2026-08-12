---
name: distill-bug
description: Turn this session's findings into a short, verified bug report ready to file. Re-checks every code claim against source at the named version, separates verified from inferred, ends with paste-ready issue text. Use before posting an investigation as a GitHub issue or Slack message.
---

# distill-bug

Outbound twin of humanize-issue: it turns this session's investigation into a report the reader can act on
without re-deriving anything.

## Process

1. Collect every factual claim the report rests on. Re-verify each against the source at the version the
   bug targets (a checkout or the module cache, never memory). A claim that cannot be re-verified is
   labeled unverified inline, never silently kept.
2. Sort findings by severity, one short heading each, plain names (no invented labels or numbering
   schemes). Each finding: a one-sentence claim, the evidence as file:line citations, then impact.
3. Mark every statement as one of: verified against source, reproduced by running, inferred. An inference
   must never read as fact.
4. State what was not checked. A bounded claim beats an implied-complete one.
5. If a finding is security-sensitive (remote crash, credential or data leak), flag it first and ask
   whether it goes through an advisory flow before producing any public text.
6. End with the paste-ready issue: a title and a body of plain prose, a repro block, and the affected
   versions. No Summary/Steps/Expected scaffolding unless the target repo's issue template requires it.

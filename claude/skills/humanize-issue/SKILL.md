---
name: humanize-issue
description: >
  Distill an LLM-generated GitHub issue or comment into a short triage summary that separates hard evidence
  from unverified claims, then optionally verify each code claim against the real source at the reported
  version. Use on any issue that arrives as a wall of LLM prose. Args: an issue URL, owner/repo#number,
  or a comment link. Add "investigate" to go straight from distillation to claim verification.
---

Turn a machine-written issue into something a maintainer reads in 30 seconds, then verify what it claims.

The trap to avoid: trusting confident prose. LLM-written reports cite file:line, quote code, and say
"confirmed by reading source". Any of it can be invented, including code blocks that look copied but were
generated. Logs, stack traces, and API output the reporter captured are evidence. Everything the reporter
concluded is a claim until you have read the code yourself.

## Fetch

Parse the argument:

- `https://github.com/OWNER/REPO/issues/N` or `OWNER/REPO#N`:
  `gh issue view N --repo OWNER/REPO --json title,body,comments`
- A `#issuecomment-<id>` anchor: also `gh api repos/OWNER/REPO/issues/comments/<id>`. Distill that comment
  as the subject, with the issue body as context.
- No issue reference: treat text pasted in the conversation as the source and skip fetching.

## Distill

Compress, do not rewrite. Produce:

- **Problem**: one line. What breaks, in which component, on what trigger.
- **Setup**: versions, platform, and config that matter. Nothing else.
- **Repro**: the minimal steps as given. Mark gaps rather than inventing steps.
- **Evidence**: captured artifacts verbatim (stack trace, log lines, API responses), trimmed to the lines
  that matter. This is the only part of the issue that can be taken at face value.
- **Claims**: numbered, one line each. Every code-level assertion goes here: file:line cites, quoted
  source, root-cause reasoning, "still present in main", "confirmed by reading source". Never promote a
  claim into Problem or Evidence.
- **Missing**: what a maintainer would have to ask for.

Reduce marketing certainty ("100% reproducible", "blocks the entire feature") to the underlying fact
("reproduced 5 times with 2 certs"). Keep the reporter's numbers and version strings exactly. Report
dropped padding as a single count, not a list.

Close with one line on how machine-generated the report reads and the strongest tell. This calibrates how
much to trust the untested parts.

If the argument included `investigate`, continue straight into the next section. Otherwise end with:
verify claims 1 through N against source, reply `investigate`.

## Investigate

Locate the source two ways and use both:

- A local checkout when one exists (look under `~/dev`, then ask). Good for `rg` across the codebase and
  reading callers. Its checked-out ref likely differs from the reported version, so never verify line
  numbers against it.
- The exact reported version, for line-accurate checks: fetch the cited files pinned to the tag into the
  scratchpad, `curl -s https://raw.githubusercontent.com/OWNER/REPO/<tag>/<path>`. Resolve the tag from
  the reported version. When a claim says "still present in main", fetch the same path at the default
  branch too.

Never clone, fetch, or checkout anything. Raw file fetches and the local checkout cover it.

Per claim, answer in order: does the cited file exist, does the quoted code appear in it, is it at or near
the cited line, and does the surrounding logic actually support the stated root cause. Read the callers
when the reasoning spans functions. A line number off by a handful is normal. Code that appears nowhere in
the repo is fabricated.

Verdict per claim:

- **CONFIRMED**: the code matches and the reasoning holds.
- **MISLOCATED**: real code, wrong file or line cited.
- **UNSUPPORTED**: the code exists but does not behave as claimed.
- **FABRICATED**: no such code at the reported version or the default branch.

With more than 3 claims, fan out one Explore agent per claim in a single message. Give each the repo, tag,
the claim verbatim, and the fetch instructions above. Each returns a verdict plus the real code cite.

Report: one line per claim (number, verdict, actual file:line, the decisive fact), then the bottom line.
Is there a real bug, what is the actual defect, and where does a fix go. Quote the real code for anything
CONFIRMED or UNSUPPORTED so the next reader does not repeat the check. Draft a reply to the reporter only
on request.

## Never

- Never post a comment, edit the issue, or change labels.
- Never present an unverified claim as fact, in any output.
- Never fix anything. The deliverable is the triage summary and verdicts.

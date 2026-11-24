---
name: draft
description: >
  Draft a commit message, PR body, issue or chat message in the user's own voice, matched against what they actually
  wrote before (their pushed commits on origin, their own PRs and issues), never against the agent's commits in this
  clone. Use whenever the user asks for a commit message, a PR body, an issue or a message to send. Args: the kind and
  the repo, when the conversation does not already say.
---

Type `~` paths literally and unquoted so bash expands them.

## Samples

Read the user's own writing of the same kind before the first draft. The local branch in the agent VM holds the agent's
commits, which perusal hands to the user as unstaged changes and the user recommits in their own words, so it is never
a sample.

- Commit message: `git -C <repo> fetch origin`, then
  `git -C <repo> log origin/HEAD --author="$(git -C <repo> config user.name)" --format=%s -15`. When `origin/HEAD` is
  missing, use the branch `gh repo view <owner/repo> --json defaultBranchRef` names.
- PR body: `gh search prs --author @me --repo <owner/repo> --limit 3 --json number`, then
  `gh pr view <number> --repo <owner/repo> --json title,body` for each.
- Issue: the same with `gh search issues` and `gh issue view`.
- Chat message: the user's own prompts in this session.
- A repo with fewer than 3 samples of that kind widens to the owner's other repos (`--owner <owner>` in place of
  `--repo`).

The repo's context file under `~/dev/agents/context` may set a format for that repo (desktop-edge-win PR bodies), and
it wins over the samples.

## Write

- Draft from what changed, never from the session's memory of the work: `git -C <repo> --no-pager diff` of the files
  being committed, or `git diff` of the branch against its base for a PR.
- Match the samples: length, casing, tense, prefixes or none, punctuation, how much they explain. A sample set of
  short plain subjects gets a short plain subject, even when the change has more to say.
- When the user gave a draft, edit theirs instead of writing a new one.
- Lead with the point. Add no context or reasoning the user did not state, and no greeting or lead-in.
- Commit message: one line, the biggest behavior change first.
- PR body: one bullet per behavior change in plain words, plus `Closes #N` when an issue is closed. No Summary or Test
  plan headings.
- Issue: open with what should happen or what is broken ("ZDEW should ...", "ZET sends two replies to ..."), then
  bullets or repro steps. A related issue or PR goes on the first line as `Related to owner/repo#N`.

## Report

The draft in full, in a fenced block, and nothing else.

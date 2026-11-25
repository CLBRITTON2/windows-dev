---
id: no-history-comments
applies_to:
  - all code
territory:
  - "**/*.go"
  - "**/*.cs"
  - "**/*.c"
  - "**/*.h"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.py"
  - "**/*.rs"
  - "**/*.lua"
  - "**/*.ps1"
  - "**/*.sh"
---

## statement

A comment must still be true and useful in a year to someone with no memory of the change. It never describes the
change, the fix, how a cause was found, the machine it ran on, or work still to do.

## why

That content belongs in the commit message or the project notes. In the code it reads as changelog prose and goes
stale the day the branch merges.

## discrimination

Flag a comment that mentions:

- a CI runner, a run id, a developer machine, a dev folder or "on the VM"
- a past failure or what the code used to do ("previously", "now", "added so that", "fixes the flake")
- an issue to track or follow up on ("TODO track in #123", "remove once X lands")

## example

Bad:

```csharp
// slow on the GitHub runner, so wait longer here
// TODO: track the remaining flake in #1104
```

Good: no comment. The timeout and the issue go in the commit message.

## boundary

A pointer to an upstream bug that explains why code is shaped oddly is allowed: `// tlsuv ignores the proxy path,
openziti/tlsuv#412`. The test is whether the comment explains the code as it stands, not the history of the edit.

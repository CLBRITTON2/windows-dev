---
id: one-name-per-concept
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

A new name for something the code already names takes the existing name: within the repo, and across a repo it mirrors,
such as a desktop app's tests and the integration tests of the daemon it drives.

## why

One concept gets one name, so a reader who knows one file or repo reads the other without translating.

## discrimination

Flag:

- a new function, type, field or test helper that does what an existing one does, in this repo or in the repo it
  mirrors, under a different name
- a synonym for a term the surrounding code uses everywhere, such as `fetch` where every sibling says `load`
- a new name built from generic words where the mirrored repo already has a specific name for the same thing

## example

Bad: `WaitForZetLine` in ZDEW's UI tests as the shared poll behind `WaitForZetReplyTo` and `WaitForZetEventAfter`,
where ZET's Go integration tests under `tests/integration` in `openziti/ziti-tunnel-sdk-c` name the same wait
differently.

Good: the name ZET's integration tests use for the same wait.

## boundary

Do not flag a name with no existing counterpart that is named for what it does. Name the existing identifier and its
file in the finding.

---
id: reuse-existing-pattern
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

New code follows the nearest existing code that does the same job: the same shared helpers, the same shape, the same
depth.

## why

A second pattern for the same job splits the codebase and drops the care the first one already took, such as freeing
memory, logging and error paths.

## discrimination

Flag:

- new code that frees, parses, sends or waits by hand where a shared helper in the repo already does it
- a new event handler, command or test much shallower than its siblings, with no logging, error path or state update
  where they have one
- a new helper whose job an existing helper already does under another name

## example

Bad: a new ZET IPC command that frees its request fields by hand while the other commands call the shared free
helper.

Bad: a toast handler that only shows the toast, where the other event handlers also update the identity row and log.

Good: copy the shape of the closest sibling and call the same helpers.

## boundary

Name the sibling the finding compares against. Do not flag a departure the commit or a one-line comment explains.
When the sibling's shape logs a failure before rethrowing, the finding also names each caller in the change whose catch
logs that same failure, and asks for that log to go, so one round fixes both sides instead of the next round flagging
the double log.

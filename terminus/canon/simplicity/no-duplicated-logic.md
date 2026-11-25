---
id: no-duplicated-logic
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

The change writes each piece of logic once. Two blocks in the change that do the same job share one implementation.

## why

Duplicated logic gets fixed in one copy and not the other, and the reader has to diff the copies to learn whether
they differ on purpose.

## discrimination

Flag:

- two or more blocks the change adds, in one file or across files, that do the same steps with different names or
  literals
- a block the change copies from existing code and edits slightly, where calling or extending the original works
- the same multi-step setup repeated across new tests where the repo's other tests share a helper for it

## example

Bad: two new commands each build the same request, send it, and parse the same reply shape with their own copy of
the code.

Good: one function that sends the request and parses the reply, called by both commands.

## boundary

Do not flag two or three similar lines, where sharing them would read worse than the repeat, or test cases that
spell out their own inputs and expectations on purpose. A shared version that reads worse than the copies is not a
fix: say so instead of flagging.

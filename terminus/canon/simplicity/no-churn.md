---
id: no-churn
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

The change touches only the lines the task needs. It does not reword, rename, recase, reorder or reformat code it
had no reason to change.

## why

Every changed line costs review time and blame history, and churn hides the lines that matter in the diff.

## discrimination

Flag a changed line whose change:

- rewords an existing comment, message or string the task did not need to change
- renames or recases an identifier the task did not change the meaning of
- reorders functions, imports, fields or cases with no change in behavior
- reformats code by hand in a way the repo's formatter would not produce

## example

Bad: a fix to one condition in `reconnect` also rewrites three nearby log messages and renames `retries` to
`attempts`.

Good: the condition changed, nothing else in the function touched.

## boundary

Do not flag output of the repo's own formatter, code moved to where the change needs it, a rename the task requires
because the thing now does or holds something else, or a comment the change made wrong.

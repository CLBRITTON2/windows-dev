---
id: change-has-test
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

A change in behavior or a bug fix comes with a test that fails without it, where the repo already tests that code.

## why

A fix with no failing test can regress unseen, and a reviewer cannot tell whether the change does what it claims.

## discrimination

Flag:

- a bug fix in code the repo already has tests for, with no new or changed test that fails on the base
- a new branch, command, option or error path in tested code with no test that reaches it
- a test added for a fix that would pass on the base just as well

## example

Bad: a fix to how `ParseProxyConfig` handles an empty port, with no test, while `ParseProxyConfig` has a table of
tests beside it.

Good: a new row in that table with an empty port, which fails on the base and passes with the fix.

## boundary

Do not flag code the repo has no tests for and no harness to test, a change to scripts, docs, configs or build
files, or a refactor that keeps behavior and leaves the existing tests passing. Name the test file the change should
have touched.

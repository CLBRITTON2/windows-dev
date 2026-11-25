---
id: no-single-use-helper
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

No new function with one caller and no new constant used once. The code or value goes where it is used.

## why

A single-use helper adds a name to learn and a jump to read, and saves nothing.

## discrimination

Flag a function or constant the change adds that has exactly one caller or use, including a test helper added for a
single edge-case test.

## example

Bad: `SetProxyWithoutProxy` added to `testutil/ipc.go` so one test, `rejectsSetProxyWithoutProxy`, can call it.

Good: the request built inline in that one test, or no test for a case the other commands leave untested.

## boundary

Do not flag an exported API, a function a test framework needs as its own boundary (a `t.Helper()` wait), or a new
helper that matches a pattern of same-shaped helpers the repo already has.

Do not flag a helper of ten or more lines that is one whole protocol exchange (open a socket or pipe, send the
request, read and return the reply), such as `SendConnectAsync` called by `TestAsync`, or a pure function whose early
returns map a reply to a result, such as `DescribeConnectReply`. Inlining either mixes I/O or a mapping into a caller
that sets UI or state. A helper that only wraps one call in a try/catch, or builds one path, is still flagged.

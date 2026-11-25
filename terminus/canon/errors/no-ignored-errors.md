---
id: no-ignored-errors
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
  - "**/*.ps1"
  - "**/*.sh"
---

## statement

The change handles every error it can receive: it returns, raises, logs or asserts it. It never discards one.

## why

A discarded error hides the failure where it happened, and the next symptom shows up somewhere unrelated.

## discrimination

Flag new code that:

- assigns an error to `_` or drops a returned error (`_ = proc.Wait()`, `stdin.Close()` with its error unread)
- catches an exception with an empty body, or one that only returns a default
- ignores a C return code or a callback's status argument
- uses `-ErrorAction SilentlyContinue`, `2>/dev/null`, `|| true` or `try { } catch { }` to hide a failing command

## example

Bad:

```go
require.NoError(t, postureProcess.Process.Kill())
_ = postureProcess.Wait()
```

Good: assert the error the kill is expected to cause.

```go
require.NoError(t, postureProcess.Process.Kill())
var exitErr *exec.ExitError
require.ErrorAs(t, postureProcess.Wait(), &exitErr)
```

## boundary

Do not flag code the change does not touch. Do not flag a call documented never to fail on that path, such as Go's
`bytes.Buffer.Write`, or a probe whose failure is the expected answer, such as `Test-Path` or a `2>/dev/null` on a
lookup the next line checks.

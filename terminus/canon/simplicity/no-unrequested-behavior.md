---
id: no-unrequested-behavior
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

The change does what the task asked and keeps the existing behavior it touches. No new validation, retries, fallbacks
or options beyond that.

## why

Every extra check is code to review and maintain, and it can reject inputs the old code accepted.

## discrimination

Flag:

- validation the old code path did not have and the task does not need (path, length, format checks)
- retries, backoff or fallbacks in scripts, tests or one-shot commands
- a rewrite of both sides when the task was to make one side match the other
- a function that grew well past the size of the code it replaced

## example

Bad: `parse_proxy_url` grows to 42 lines with path, query and length checks main never had, so `-x` now rejects URLs
main accepted.

Good: keep main's checks (parse, scheme, hostname, port) and propose any extra check as a separate change.

## boundary

Do not flag a check that prevents a failure the change itself would otherwise cause, such as saving a URL that cannot
be used at the next start. Retries in a long-running service or UI client are allowed when each retry logs a warning.

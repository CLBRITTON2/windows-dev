---
id: readable-at-a-skim
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

A helper called at the top of a test or at a decision point names its effect and its literal condition, so a reader
skimming the caller knows what happens without opening the helper.

## why

Tests are read quickly, top to bottom. A guard named for a mechanism or capability forces the reader to open it to
learn whether the test even runs.

## discrimination

Flag a helper whose name:

- names a mechanism or capability instead of the condition and effect (`requireTotpTokens`)
- hides that it skips, fails or returns early (a `require...` that calls `t.Skip`)
- is a generic verb (`check`, `setup`, `handle`, `process`, `flush`)

## example

Bad: `requireTotpTokens(t)`.

Good: `skipOnOidcBeforeZiti17(t)`. The effect (skip) and the condition (OIDC on a controller before 1.7) are in the
name.

## boundary

Do not flag existing helpers the change only calls, such as `requireMultiTunnel`. Flag a new helper even when it
copies the style of an existing unclear one.

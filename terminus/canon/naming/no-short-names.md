---
id: no-short-names
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

No one-letter names and no ad hoc abbreviations. Short forms the codebase already uses everywhere (`id`, `ctx`, `cfg`,
`resp`, `dir`, `t` in Go tests, `i` as a plain loop index) are allowed, and so is a Go method receiver of one or two
letters (`r` on `*Repository`).

## why

A short name forces the reader to find its declaration to learn what it holds.

## discrimination

Flag a new name that is:

- one letter, other than a plain loop index, the test handle or a Go method receiver
- an abbreviation the file does not already use everywhere (`srv`, `cli`, `tmp`, `buf`, `res`, `req`, `msg`, `val`,
  `obj`, `arr`, `idx`, `cnt`, `evt`, `vm`)

## example

Bad: `srv` for a `NamedPipeServerStream`, `s` for an `AppiumSession`, and `e`, `o`, `arr` in a fixture builder.

Good: `pipeServer`, `session`, `identityEvent`, `fixtureIdentities`.

## boundary

Do not flag names in code the change only moves. Do not flag names that mirror a sibling repo on purpose, such as a
port of a ZET test helper that keeps ZET's parameter names.

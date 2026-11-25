---
id: name-follows-body-order
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

A function named for the steps it performs lists them in the order the body runs them, and leads with the step the
reader cares about.

## why

A reader skimming a call site trusts the name as a summary of the body. A name that lists the steps out of order, or
leads with a minor one, sends the reader into the body to learn what happens.

## discrimination

Flag:

- a name of the form `aAndB` or `aThenB` whose body does B first
- a name that leads with a minor setup step while the main work is the second step
- a name that omits the main step the body performs

## example

Bad: `startEchoAndEnroll`, where the main work is the two enrolls and the echo server is setup.

Good: `enrollAndStartEcho`, with the body enrolling first and starting the echo server last.

## boundary

Do not flag a name that describes the result rather than the steps (`SavedProxyLogins`). Only names built from step
verbs are checked for order.

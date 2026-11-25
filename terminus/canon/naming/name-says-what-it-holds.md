---
id: name-says-what-it-holds
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

A type, variable or function is named for what it holds or does, in words the code and its domain already use. No
container words that hide the contents and no coined terms.

## why

A container word says how something is kept, not what it is. A coined term makes the reader stop and ask what it
means.

## discrimination

Flag a new or renamed identifier that:

- ends in a container word that does not say what is inside (`Store`, `Manager`, `Helper`, `Data`, `Info`, `Util`)
- coins a term the code and its domain do not use ("digest sessions", "sent service")
- is a generic word (`found`, `status`, `props`, `added`, `result`, `data`)
- carries a bare number or time with no unit (`timeout` holding milliseconds)

## example

Bad: `ProxyLoginStore`, called as `ProxyLoginStore.Saved(host, port)`.

Good: `SavedProxyLogins`, called as `SavedProxyLogins.Saved(host, port)`.

## boundary

Do not flag names the change does not introduce or rename. A container word is fine when the thing is exactly that
container and its type says what it holds.

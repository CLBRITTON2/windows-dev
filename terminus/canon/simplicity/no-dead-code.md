---
id: no-dead-code
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

The change leaves no code that nothing reaches: no function, type or constant without a caller, no unreachable
branch, no parameter the body ignores, no unused import or variable.

## why

Dead code is read, reviewed and maintained like live code, and a reader cannot tell it is dead without searching.

## discrimination

Flag:

- a function, type, constant or file the change adds or leaves with no caller in the repo
- a branch the change makes unreachable, such as a check for a case the caller can no longer pass
- a parameter the change stops using, still passed by every caller
- an import, variable or field the change leaves unused
- code commented out instead of deleted

## example

Bad: a refactor moves the proxy parse into `ParseProxyConfig` and leaves the old `parseProxy` in place with no caller.

Good: `parseProxy` deleted in the same change.

## boundary

Do not flag an exported API used outside the repo, a function a framework calls by name or reflection (a test, a
handler, an interface method), or code the change did not touch that was already dead on the base. Name the code
and say where you searched for callers.

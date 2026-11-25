---
id: test-can-fail
applies_to:
  - tests
territory:
  - "**/*_test.go"
  - "**/*Tests.cs"
  - "**/*Test.cs"
  - "**/*.test.ts"
  - "**/*.test.js"
  - "**/test_*.py"
  - "**/tests/**"
  - "**/Tests/**"
---

## statement

Every test asserts the state it exists to prove, in a way that fails if the code under test is wrong.

## why

A test that cannot fail gives false confidence and hides the bug it was written for.

## discrimination

Flag a test that:

- checks a value the code under test never changes on that path, such as a file only written on success checked
  after a rejection
- waits for an event but asserts nothing about its content
- asserts less than its siblings check for the same kind of object, such as a posture check test that does not assert
  `IsPassing` and `IsAccessible` where the other posture check tests do
- was changed to pass with no matching change in the code under test
- was deleted without its check moving somewhere it can fail

## example

Bad: `rejectedProxyKeepsSavedProxy` sends a bad proxy, then checks `config.json` still holds the first one. ZET writes
`config.json` only when a command succeeds, so the check passes even if ZET replaced the proxy in memory.

Good: send the bad proxy, restart ZET, and assert the proxy it logs after the restart is the first one.

## boundary

Do not flag a smoke test whose name says it only checks that something runs without error. Do not flag a change for
extending a test pattern that already exists on the base branch, such as adding a field to a test-local copy of a
production class: the weakness predates the change.

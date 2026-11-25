---
id: test-name-states-the-rule
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

A test name states the operation, the outcome and the condition, in terms of the rule under test. A scenario test
names its sequence of steps.

## why

The list of test names is the specification a reader skims. A name built from a sample input does not say which rule
broke when it fails.

## discrimination

Flag a test name that:

- names a sample value instead of the rule (`rejectsSocks5Proxy` for an unsupported-scheme check)
- leaves out the operation or the outcome (`withValidTotp`, `invalidProviderFails`)
- names only one step of a multi-step scenario

## example

Bad: `rejectsSocks5Proxy`.

Good: `setProxyRejectsUnsupportedScheme`.

Good, for a scenario: `serviceAccessRevokedByMfaCheckAndRestoredByMfaEnroll`.

## boundary

Do not flag names that drop words the package already says. Length is not a defect when every word carries the rule.

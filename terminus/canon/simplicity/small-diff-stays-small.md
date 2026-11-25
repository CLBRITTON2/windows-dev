---
id: small-diff-stays-small
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

A fix replaces a line with the smallest readable change. A compound condition gets a named local that states the rule,
not a longer one-liner.

## why

The reviewer has to verify every clause. One long line of `&&` and `||` hides which clause is the fix.

## discrimination

Flag:

- a one-line change that becomes a line with three or more boolean clauses
- a new chain of null checks joined by `&&` where `?.` or a named local reads as one rule
- a line over 150 characters that the change introduces

## example

Bad:

```csharp
updatedIdentity.IsMFANeeded = e.Id.MfaNeeded || (!e.Id.MfaEnabled && zid.Services.Any(s => s.PostureChecks != null && s.PostureChecks.Any(p => !p.IsPassing && p.QueryType == "MFA")));
```

Good:

```csharp
bool deniedUntilMfaEnrolled = !zid.IsMFAEnabled && service?.PostureChecks?.Any(p => !p.IsPassing && p.QueryType == "MFA") == true;
if (deniedUntilMfaEnrolled) {
    zid.IsMFANeeded = true;
}
```

## boundary

Do not flag long lines the change only moves. Do not demand a named local for a condition of two plain clauses. Do
not flag a long line that copies the shape of a sibling on the base branch, such as a one-line `return new
SvcResponse { ... }` beside siblings that return the same way.

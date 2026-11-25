---
id: no-narrating-comments
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

Code carries no comment by default. A comment is allowed only for the purpose of a block whose effect the code does not
show, a non-obvious constraint, a gotcha, the reason arbitrary-looking code must be this way, or a pointer (issue
number, URL, spec section, upstream bug). It is one terse line.

## why

Comments that restate the code double the reading and rot as the code changes. The reader trusts the code, so a
comment has to carry something the code cannot.

## discrimination

Flag a comment that:

- narrates what the next line or block does
- restates a well-named identifier, or would be unneeded if the identifier were renamed
- is a multi-line doc comment that lists the steps of a short function
- is a doc comment (`///`, `/** */`, `"""`, Go's `// Name ...`) whose sentence the member's name and type already say
- is a doc comment longer than one line, unless every line is a constraint, a gotcha or a pointer
- lists what a member returns or throws (`null when ...`, `Throws X when ...`) that its signature or body already shows
- uses words the code never defines ("hold false", "sent service", "to the lock")
- appears on most lines of a block, or on most members of a type, especially in tests

## example

Bad: a doc comment that walks through the body.

```go
// startEchoAndEnroll starts the echo server at echoAddr, where the fixture.json host config of hostID forwards
// tunneled connections, enrolls hostID on the host ZET and clientID on the client ZET, and waits for the one service
// of clientID.
func startEchoAndEnroll(t *testing.T, echoAddr, clientID, hostID string) (testutil.IdentityEvent, testutil.BulkServiceEvent)
```

Good: one line for the one fact the code cannot show.

```go
// echoAddr is where the fixture.json host config of hostID forwards tunneled connections.
func enrollAndStartEcho(t *testing.T, clientID, hostID, echoAddr string) (testutil.IdentityEvent, testutil.BulkServiceEvent)
```

Bad: a summary on every member, restating its name and its null and throw cases.

```csharp
/// <summary>
/// The mode in the monitor's last status event, null until an event reports it.
/// </summary>
public ProxyMode? ReportedMode { get; private set; }
```

Good: no comment on `ReportedMode`, and one line where the code hides a gotcha.

```csharp
/// <summary>Each non-zero string is freed with GlobalFree.</summary>
internal struct WINHTTP_CURRENT_USER_IE_PROXY_CONFIG
```

## boundary

Do not flag comments present on the base branch that the change leaves true. Do not flag a one-line comment that
gives a reason, a constraint or a pointer. A one-line doc comment is allowed only where a linter the repo runs requires
one on that identifier.

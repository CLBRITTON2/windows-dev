# Code rules

The rules terminus reviews against (naming, comments, tests, simplicity) live only in its canon,
`~/dev/agents/terminus-canon`, one file per rule. Read them before writing code. The rules below are the rest.

## Code style

- Strict typing everywhere: function returns, variables, collections. Avoid `any`, `unknown`, `var`,
  `List[Dict[str, Any]]`.
- Prefer structured data models over loose dictionaries. Create proper type definitions for complex
  structures.
- No default parameter values. Make every parameter explicit.
- Write pure functions: modify return values, never input parameters or global state.
- Single purpose per function. No multi-mode behavior, no flag parameters that switch logic.
- Plain `if`/`else` that assigns in each branch. Never a ternary, and never assign a value then overwrite it.
- Keep OOP simple and readable with limited inheritance.
- All imports at the top of the file.
- Follow DRY, KISS, YAGNI. Check whether the logic already exists before writing new code.

## Naming

- Where a file already has a naming pattern (casing, initialisms, prefixes), match it over these rules.
- Name a function for the steps it performs or the command it calls, not a generic verb: `EnrollAndEnableMFA`, not
  `SetupMFA`. `SendPendingNotifications`, not `Flush`.
- Name for the concept, not the tool or transport behind it: `OpenCommandPipe`, not `DialIPC`. `DriveIdPFlow`, not
  `DrivePKCEFlow`.
- A method that only returns a value is a noun, with no `Get` or `Resolve`: `PayloadEnrollMode`, `SavedZetConfig`.
- A parameter says what it is for, not its shape: `destination`, not `folder`.
- When a change alters what a thing does or holds (scheme, unit, one vs many), rename it in the same change:
  `HttpUrl` to `HttpsUrl`, `StableFrameTimeoutMs` to `StableFrameMaxCaptures`, `PurgeIdentitiesByExternalId` to
  `PurgeIdentityByExternalId`.
- An assert helper names the exact fact it checks: `assertMfaEnabled`, not `assertValidMfaIdState`.
- Drop words the context already says: `RunWithTimeout` in a test package, not `RunTestWithTimeout`.

## Comments and docs

- Leave existing comments alone unless your change makes one wrong, then fix or delete it. Existing means present
  on the base branch: a comment this branch added is yours to fix. English only.
- Never decorate with banners and `==== section ====` bars.
- Documentation, when the code needs it, lives in the docstring of the function or class it describes. Separate docs
  files only when a concept cannot be expressed in code. Never duplicate documentation across files.

## Error handling

- Raise errors explicitly. Never silently ignore them.
- Use specific error types that indicate what went wrong. Avoid catch-all handlers that hide the cause.
- Error messages must be clear, actionable, and carry enough context to debug: request params, response
  body, status codes.
- No fallbacks unless I explicitly ask for them.
- Retry external API or service calls only in long-running processes (services, daemons, UI clients): warn on each
  retry, then raise the last error. Scripts and CI steps call once and fail, since a rerun is the retry.
- Logging uses structured fields, not dynamic values interpolated into the message string.

---
paths:
  - "**/*.{go,rs,c,h,cc,cpp,hpp,cs,java,kt,swift,zig}"
  - "**/*.{js,jsx,mjs,cjs,ts,tsx,vue,svelte}"
  - "**/*.{py,rb,lua,php,pl}"
  - "**/*.{ps1,psm1,psd1,sh,bash,zsh,cmd,bat,ahk}"
  - "**/{CMakeLists.txt,*.cmake,Makefile,Dockerfile}"
---

# Code rules

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
- No function with one caller and no constant used once: write the code or value where it is used.

## Naming

- Where a file already has a naming pattern (casing, initialisms, prefixes), match it over these rules.
- Name a variable for what it holds, never a generic word (`found`, `status`, `props`, `added`) or a letter or number
  (`zetA`, `$wad1`): `identityViewModel`, `zetClient`, `authStatusEvent`, `addResp`.
- No ad hoc abbreviations (`vm`, `evt`). Short forms the codebase already uses everywhere (`id`, `ctx`, `cfg`, `resp`,
  `dir`) are fine.
- Name a function for the steps it performs or the command it calls, not a generic verb: `EnrollAndEnableMFA`, not
  `SetupMFA`. `SendPendingNotifications`, not `Flush`.
- Name for the concept, not the tool or transport behind it: `OpenCommandPipe`, not `DialIPC`. `DriveIdPFlow`, not
  `DrivePKCEFlow`.
- A method that only returns a value is a noun, with no `Get` or `Resolve`: `PayloadEnrollMode`, `SavedZetConfig`.
- A parameter says what it is for, not its shape: `destination`, not `folder`.
- When a change alters what a thing does or holds (scheme, unit, one vs many), rename it in the same change:
  `HttpUrl` to `HttpsUrl`, `StableFrameTimeoutMs` to `StableFrameMaxCaptures`, `PurgeIdentitiesByExternalId` to
  `PurgeIdentityByExternalId`.
- A bare number or time carries its unit in the name: `PollIntervalMs`, `savedAtUtc`. A typed duration needs none.
- An assert helper names the exact fact it checks: `assertMfaEnabled`, not `assertValidMfaIdState`.
- A test name states operation, outcome and condition: `reauthAcceptsValidTotp`,
  `enrollToNoneRejectsInvalidProvider`. Not `withValidTotp` or `invalidProviderFails`.
- Drop words the context already says: `RunWithTimeout` in a test package, not `RunTestWithTimeout`.
- One concept gets one name across files, not a synonym per file.

## Comments and docs

- Default to writing no comment, especially in tests. Add one only for a case in the next bullet, as one terse line.
  Never write one that explains a fix, what changed, or how a cause was found: that goes in the commit or the agents
  repo. Leave existing comments alone unless your change makes one wrong, then fix or delete it. English only.
- Write a comment for: the purpose of a block whose effect is not visible in the code, a non-obvious
  constraint (ideally on the same line as the purpose), a gotcha or landmine, why arbitrary-looking code has
  to be this way (the reason, not the mechanism), or a pointer (issue number, URL, spec section, upstream
  bug).
- Never write a comment that narrates the line, restates a well-named identifier (rename it instead), reads
  as changelog prose ("added this so builds are faster", a CI run id, a past failure, "slow on the runner"), or
  decorates with banners and `==== section ====` bars.
- Comment the surprising line, not every line. A comment on every line means none of them is worth reading.
- The test before writing one: can the reader see it from the code? If yes, write nothing. Will it still be
  true and useful in a year to someone with no memory of this edit? If it only makes sense as a note about
  the change, it is a commit message.
- Documentation lives in the docstring of the function or class it describes. Separate docs files only when
  a concept cannot be expressed in code. Never duplicate documentation across files.

## Error handling

- Raise errors explicitly. Never silently ignore them.
- Use specific error types that indicate what went wrong. Avoid catch-all handlers that hide the cause.
- Error messages must be clear, actionable, and carry enough context to debug: request params, response
  body, status codes.
- No fallbacks unless I explicitly ask for them.
- External API or service calls: retry with warnings, then raise the last error.
- Logging uses structured fields, not dynamic values interpolated into the message string.

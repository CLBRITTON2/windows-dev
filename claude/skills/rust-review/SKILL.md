---
name: rust-review
description: >
  Review Rust application code (a CLI, daemon, or tool crate) against a checklist built from the Rust API
  Guidelines, the Book, Clippy, large Rust repos, and the user's naming rules: core logic kept apart from app
  glue, neutral test data, typed errors, documented unsafe. Read-only on code, reports findings with file:line and
  records them in the repo's review ledger so each run builds on the last. Args: a path or diff range to scope the
  review, otherwise what changed since the ledger's last run.
---

# Rust review

> Experimental: this skill was vibe-coded, and its checklist has not been checked against reviews by Rust
> developers. Take its findings as you will.

Review the crate, report findings, and record them in the repo's review ledger. Never edit code and never run a git
mutation. The ledger and the report are the deliverables.

## Ledger

Each repo keeps one ledger at `~/dev/agents/context/<repo>/reviews/rust.md`, so a run builds on the last one instead
of starting from scratch. Create it with the sections below when it is missing, and list it under the context
`CLAUDE.md`'s `## Detail files`. It holds, in this order:

- `Last reviewed: <short hash> (<date>)`, the commit the last run reviewed.
- Coverage: a table of each module, the depth of its last pass (`deep`, `broad`, `none`) and the commit.
- Open: one line per finding, `RUST-<n> <checklist id> <severity> file:line what is wrong, and the fix`. Severity is
  `high` (soundness, bugs), `medium` (design, tests) or `low` (naming, idioms).
- Parked: open findings the user chose to leave for later, in the same form.
- Settled: `RUST-<n> <checklist id> fixed <short hash>`, and what changed in one line.
- Rejected: findings a reader could fall for that are wrong or deliberate here, with the reason.
- Heuristics: project facts that make the next run faster or sharper, such as deliberate patterns and where the OS
  calls and trust boundaries are.

Ids are never reused. Current state only, no narration of a run. Prose: no em dash, no double hyphen as a dash, no
semicolons, wrap at 120 columns.

The session that fixes a finding moves it to Settled with the fixing commit. Parking a finding is the user's call.

## Steps

1. Read the repo's `CLAUDE.md`, `Cargo.toml` (edition, `[lints]`, dependencies), the binary's `main.rs` and the
   ledger. Project rules win over this checklist where they conflict.
2. Scope, when no path or range was passed: `git log --oneline <last reviewed>..HEAD` and the full diff of that range,
   plus the modules the coverage table lists as `broad` or `none`. With no `Last reviewed`, the whole crate.
3. Run the tooling and keep the output for the report:
   - `cargo fmt --check`
   - `cargo clippy --all-targets -- -W clippy::pedantic -W clippy::undocumented_unsafe_blocks` (flags for this run
     only, not a config change)
   - the repo's test script, or `cargo test --all-targets`

   Quote the first lines of any failure. A point Clippy already flagged is cited by its lint name, not repeated.
4. Read every file in scope against the checklist. Start with design (D) and test data (T1, T2): they decide the
   shape of everything else, and a finding there makes many smaller ones moot.
5. Before raising a finding, search the ledger's Open, Parked, Settled and Rejected entries. Raise a settled or
   rejected item again only when the code under it changed in a way that defeats its reason, citing `file:line`.
6. Write the ledger: `Last reviewed` set to `HEAD`, a coverage row for each module read, new findings under Open with
   the next free id, findings the code now fixes moved to Settled, new false positives under Rejected, and any new
   heuristic.
7. Report.

## Report

One finding per line: `RUST-<n> file:line ID what is wrong, and the fix`. Order: soundness and bugs, then design,
tests, naming, idioms. Repeats of one check become one finding that lists every site. Then the ids moved to Settled.
No praise and no list of what passed. Say "no findings" when there are none.

## Checklist

Source tags are listed under Sources at the end. A point with no tag is the user's rule.

### D. Design: core logic apart from app glue

- **D1** Core types (session, window, workspace, plan) never name a specific program, product, or person. What an
  app needs (how to detect it, key it, relaunch it) lives in one adapter module per app, reached through one
  registry function, and the core sees only an enum or a small struct the adapter returns. A `claude_session_id`
  field on a core struct, or `match process_name { "wezterm.exe" => ... }` inside restore logic, is a finding.
  [RA-arch, ruff crate layout]
- **D2** Wire formats stay at the edge. A type deserialized from another tool's IPC or JSON is converted into a
  crate-owned type at the boundary and is never persisted as-is. `#[derive(Serialize)]` on a core type makes it a
  file format, so question it. [RA-arch Serialization]
- **D3** A persisted format carries a schema version, and per-kind data is a `#[serde(tag = "kind")]` enum, not
  sibling `Option` fields that only one kind fills.
- **D4** IO at the edges, a pure core. Deciding (what to launch, where to move it) is a function from saved state and
  live state to a plan, testable with no Win32, no window manager, and no filesystem. Executing applies the plan. A
  function that both decides and calls the OS is a finding. [RA-arch Error Handling]
- **D5** `main` parses arguments, calls `run`, prints the error chain to stderr, and returns the exit code.
  `process::exit` appears nowhere else. [Book ch12-03, ripgrep main.rs]
- **D6** Raw input is parsed once into a validated type. Code after that point never re-checks it and never sees the
  raw strings. [ripgrep lowargs and hiargs, API C-VALIDATE, Book ch09-03]
- **D7** Behavior that differs per kind (launch once per app versus once per window) is a named enum the adapter
  returns, not a rule hidden in a `matches!` deep in the restore loop.
- **D8** No abstraction ahead of need: no trait with one implementation, no plugin or rule-config system, no workspace
  split for one binary. The second implementation earns the trait.
- **D9** Visibility is as narrow as it can be: private by default, `pub(crate)` across a binary's modules, no
  `pub use` re-exports outside a library's root. [Book ch07-02, RA-style]
- **D10** One cohesive concept per file. A file mixing the data model, persistence, OS calls and policy is split by
  concept (model, store, capture, plan, launch, platform), never by line count. [ruff, ripgrep flags/]
- **D11** OS data uses OS types: `PathBuf` and `OsString`, absolute paths, and a newtype that compares
  case-insensitively wherever Windows paths or exe names are matched. `String` equality on a path is a finding.
  [RA-style Appropriate String Types]
- **D12** Identity comes from the OS (token, SID, `GetUserNameW`), never from an environment variable like
  `USERNAME` that any parent process can set.

### T. Tests

- **T1** Test data is neutral and synthetic: `example.com`, `foo`, `user`, `app.exe`, `C:\work\project`, a title
  like `Document - Editor`. Never the user's name or account, a real machine path, a real repo name, a window title
  from a real session, or another product's name unless that product is the subject of the test (a WezTerm adapter
  test may say wezterm). A fixture copied from a live capture is a finding even when it passes. The same holds for
  doc comments that use the user's apps as examples of generic behavior. [ZET, cargo `project()`, ripgrep hay.rs]
- **T2** A fixture holds only the fields the test is about. The rest comes from one builder or helper per module. Ten
  tests repeating a fifteen-field struct literal is a finding. [RA-style Minimal Tests, ruff]
- **T3** Test names are sentences that end in the outcome, with no `test_` prefix:
  `restore_skips_window_already_open`, `existing_config_wins_over_backup`, `prefix_too_small_is_rejected`. [ZET,
  ruff, cargo, tokio]
- **T4** Each test builds its own world: a `tempfile` directory, no shared paths, no reliance on environment
  variables, the current user, or installed programs. A test that needs the real desktop runs from a separate,
  opt-in target (a cargo feature or an integration script), never by default. [ripgrep util.rs, RA-arch, uv test
  features]
- **T5** Every error path a caller can hit has a test asserting the variant with `matches!`. [API C-FAILURE]
- **T6** Tests aim at boundaries that survive refactors: the pure planner, the parsers, the store round trip. Prefer
  one `check(input, expected)` helper per module over many tests calling internals. [RA-arch Testing, uv]
- **T7** Integration tests in `tests/` need a library target, and shared helpers go in `tests/common/mod.rs`. Check
  that the repo's test script runs them: `cargo test --lib --bins` skips `tests/`. [Book ch11-03]
- **T8** A bug fix adds a minimal test that fails without it. A regression test links its issue. [cargo, nushell,
  ripgrep regression.rs]
- **T9** No `#[should_panic]`: assert on `Err` or `None`. No bare `#[ignore]`: assert the current wrong behavior and
  add a FIXME. [RA-style]
- **T10** An assertion message is absent when the assertion reads on its own, otherwise it is a step label, the
  broken expectation, or `field=value`. [ZET]

### N. Naming

- **N1** Names describe the role in the scenario, not the type: `saved`, `live`, `restored`, `old_title` and
  `new_title`, never `data`, `val`, `tmp`, `res`. A lone value of a type defaults to the type's name in snake case
  (`window_state: WindowState`). [ZET, RA-style]
- **N2** Words are spelled out. Allowed short forms: the domain initialisms `id`, `url`, `jwt`, `ipc`, `dns`, `pid`,
  `hwnd`, `cwd`, and the idioms `err`, `ctx`, `cfg`, `buf`, `idx`. Never `ver`, `ws`, `proc`, `wnd`, `rp`. [ZET,
  uv-AGENTS]
- **N3** Rust casing treats an initialism as a word: `SessionId`, `IpcClient`, `window_id`, never `SessionID`. [API
  C-CASE]
- **N4** Paired and sibling names share one form: `first` and `reuse`, `saved_at` and `restored_at`, error variants
  all verb-object (`ReadSession`, `WriteSession`, `ParseSession`). [ZET, API C-WORD-ORDER]
- **N5** An enum variant names exactly what it covers: `Key::Wezterm`, not `Key::Terminal`, when the code only handles
  WezTerm. The enum is the family, so variants do not repeat its name, and items do not repeat their module's name
  (`session::Session` is fine, `session::SessionStore` gets a second look). [ZET, clippy module_name_repetitions]
- **N6** Prefixes keep strict meanings: `assert_` only asserts, `wait_` blocks, `read_` and `load_` return data from
  IO, `new`, `from_` and `with_` construct. `as_` is free, `to_` costs, `into_` consumes. Getters have no `get_`.
  [ZET, API C-CONV, C-GETTER]
- **N7** Constants name their scope and end in a unit word (`RESTORE_TIMEOUT`, `POLL_INTERVAL`, `SETTLE_WINDOW`).
  They are `Duration` values, not bare millisecond integers, and carry a comment justifying the value. [ZET]
- **N8** A nested call whose result has meaning is bound to a named variable first:
  `let workspaces = query_workspaces(&client)?` and then the use. [ZET]
- **N9** Single letters only for closure parameters in one-line iterator chains and tiny loop indices. [ZET]
- **N10** Wire names match their counterpart exactly. A struct mirroring another tool's JSON uses that tool's field
  names through serde attributes. [ZET]
- **N11** Log and error text is lowercase with no trailing period. Logs read `component: action` with structured
  fields. Error messages are verb phrases (`#[error("reading session {path}")]`) with the cause in `#[source]`,
  never repeating the source's text. [ZET, API C-GOOD-ERR, uv STYLE.md]

### E. Errors

- **E1** Fallible means `Result`. `unwrap`, `expect`, `panic!` and indexing appear only on proven invariants, and an
  `expect` message states the invariant. `[lints.clippy]` denies the first four. [Book ch09-03, nushell]
- **E2** One `thiserror` enum per module boundary, or per crate for a small binary, with variants a caller would
  handle differently. Usage errors belong to `main`. OS calls share one variant carrying the call name, the
  arguments that matter, and the `windows::core::Error`, not one variant per API. [uv-resolver error.rs, ripgrep
  ignore]
- **E3** The cause survives: `#[source]` or `#[from]`, never `map_err(|_| ...)`. [Book ch09-02, clippy
  map_err_ignore]
- **E4** Context is added at the layer that knows it: path, pid, hwnd, command line, IPC request and response body.
  A bare `io::Error` with no path is a finding. [cargo console.html, ripgrep WithPath]
- **E5** No silent discard. `let _ =` or `.ok()` on a `Result` carries a comment saying why ignoring it is correct.
  No fallback that hides a failure, such as `unwrap_or_default` on a parse that should fail loudly. [clippy
  let_underscore_must_use]
- **E6** An expected "not available" outcome (access denied on an elevated process) is an `Option` or an enum value
  documented on the function, and only that error code maps to it. Every other error still propagates.
- **E7** `Drop` never panics and never blocks. Fallible or slow cleanup is an explicit method. [API C-DTOR-FAIL,
  C-DTOR-BLOCK]
- **E8** A call to an external service or process that can fail transiently retries with a warning, then returns the
  last error.

### A. Types and functions

- **A1** Domain values are newtypes: ids, handles, pids, kinds of path, timestamps (`SystemTime`, or seconds in a
  `u64` newtype, never a bare `u128`). [API C-NEWTYPE]
- **A2** No `bool` or `Option` parameter that selects behavior, and no `match` on a `bool`. Split the function or
  take an enum. [API C-CUSTOM-TYPE, RA-style]
- **A3** Many settings go in an explicit config struct with no `Default` impl, filled in at the call site.
  [RA-style]
- **A4** Preconditions live in parameter types: take `Window`, not `Option<Window>` checked inside. Push the branch
  up to the caller. [RA-style Function Preconditions, Control Flow]
- **A5** Collections indexed in lockstep (`titles[i]`, `pids[i]`) become one `Vec` of a struct.
- **A6** Parameters are `&str`, `&[T]`, `&Path`, `Option<&T>`. Ownership is taken only to store the value, and a
  function never clones a borrowed parameter inside. [API C-CALLER-CONTROL, RA-style, clippy ptr_arg]
- **A7** Results come back as return values. No `&mut` parameter mutated as the output, no global state. [API
  C-NO-OUT]
- **A8** `Debug` on every type. `Clone`, `PartialEq` and `Eq` where they make sense (tests need `assert_eq!`),
  `Hash` on map keys. [API C-COMMON-TRAITS, C-DEBUG]
- **A9** Conversions go through `From` and `TryFrom`. A numeric `as` cast that can truncate or wrap becomes
  `try_from`, or carries a comment proving the range. [API C-CONV-TRAITS, clippy cast_possible_truncation]
- **A10** A `match` on a crate enum is exhaustive, with no `_` arm where a new variant must be handled. [uv-AGENTS]
- **A11** Stringly typed data (event names, commands, handle values) is parsed once into an enum or newtype. A
  command sent over IPC is built by one function that quotes its arguments.
- **A12** No logic, output, or test depends on `HashMap` iteration order. [clippy iter_over_hash_type]

### U. Unsafe and FFI

- **U1** Every `unsafe` block has a `// SAFETY:` comment naming the invariant and where it was established.
  [std-dev safety comments, clippy undocumented_unsafe_blocks]
- **U2** One unsafe operation per block, safe code outside it. [std-dev, clippy multiple_unsafe_ops_per_block]
- **U3** A safe function's soundness never depends on its caller. [nomicon]
- **U4** Handles are owned (`windows::core::Owned`, `OwnedHandle`). A raw `HANDLE` is never stored or returned.
  [API C-NEWTYPE]
- **U5** Layout assumptions are explicit: a hardcoded offset into an undocumented structure is gated with
  `#[cfg(target_pointer_width = "64")]` or a compile-time assertion, and links its source.
- **U6** Pointer casts keep constness. In edition 2024 the body of an `unsafe fn` still uses explicit
  `unsafe {}` blocks. [edition guide, clippy ptr_cast_constness]

### C. Comments and docs

- **C1** A comment says what the code cannot: an invariant, a reason, a gotcha, a link. No narration, no changelog
  prose, no session or prompt leakage. [ruff-AGENTS, uv-AGENTS]
- **C2** A doc comment's first line is a one-sentence summary. Types are linked as [`Type`]. The `//!` crate doc
  says what the tool does and how its modules fit. [rustdoc, API C-LINK, C-CRATE-DOC]
- **C3** An `#[allow]` carries `reason = "..."` or is an `#[expect]`. Dead code is deleted, not allowed. [cargo
  lints, ruff-AGENTS]

### P. Performance

Most CLI code is cold. Flag these only on paths that run per window, per event, or per save.

- **P1** No full scan of an unbounded file to find one record where a tail read, index, or cache works.
- **P2** No repeated IPC or OS query for the same snapshot in one operation. Query once, pass the result down.
- **P3** Clones in loops are justified, and `Rc` or `Arc` clones are written `Arc::clone(&x)`. No `collect` that is
  only iterated once. Lazy `unwrap_or_else` where the default allocates. [clippy redundant_clone, needless_collect,
  or_fun_call]
- **P4** Large enum variants are boxed. [clippy large_enum_variant]

### K. Cargo

- **K1** Lint levels live in `[lints]`, not in scattered `#![deny]`. The lockfile is committed for a binary. No `*`
  versions. [cargo manifest]
- **K2** A direct dependency on a sibling crate of a family (`windows-core` next to `windows`) matches the version the
  family crate pulls in. `cargo tree -d` shows a split, and a dependabot group must bump the family together.
  [clippy multiple_crate_versions]
- **K3** A new dependency earns its place over std or an existing dependency. [RA-style, nushell]
- **K4** A crate with no FFI sets `unsafe_code = "forbid"`. [cargo manifest]

## Where the sources disagree

This checklist picks a side so the review is consistent:

- Abbreviations: spelled out (uv, ZET), not rust-analyzer's `res` and `it` vocabulary.
- An `impl` sits next to its struct (ruff), not after all type definitions (rust-analyzer).
- Lint suppression is local `#[expect]` with a reason (uv, ruff), never a workspace-wide allow.
- `unwrap` is denied by lint (nushell), not tolerated on locks the way ripgrep's binary does.
- Comments are terse fragments where that is clearer (user), not mandatory full sentences (rust-analyzer).
- Unit tests in the same file are fine for pure logic. Integration tests cover the CLI (cargo, uv). tokio's "avoid
  unit tests" is for a library with a large public API.

## Sources

- API: Rust API Guidelines, https://rust-lang.github.io/api-guidelines/ (point ids such as C-NEWTYPE)
- Book: The Rust Programming Language, https://doc.rust-lang.org/book/ (chapter ids such as ch09-03)
- clippy: https://rust-lang.github.io/rust-clippy/master/index.html (lint names)
- std-dev: https://std-dev-guide.rust-lang.org/policy/safety-comments.html
- nomicon: https://doc.rust-lang.org/nomicon/meet-safe-and-unsafe.html
- edition guide: https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-op-in-unsafe-fn.html
- cargo manifest: https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section
- cargo, cargo console.html: https://doc.crates.io/contrib/ (tests/writing.html, implementation/console.html)
- rustdoc: https://doc.rust-lang.org/rustdoc/how-to-write-documentation.html
- RA-style, RA-arch: rust-lang/rust-analyzer `docs/book/src/contributing/style.md` and `architecture.md`
- uv-AGENTS, uv STYLE.md, uv-resolver: astral-sh/uv `AGENTS.md`, `STYLE.md`, `crates/uv-resolver/src/error.rs`
- ruff, ruff-AGENTS: astral-sh/ruff `CONTRIBUTING.md` and `AGENTS.md`
- nushell: nushell/nushell `devdocs/rust_style.md` and `CONTRIBUTING.md`
- tokio: tokio-rs/tokio `docs/contributing/pull-requests.md`
- ripgrep: BurntSushi/ripgrep `crates/core/main.rs`, `crates/core/flags/`, `crates/ignore/src/lib.rs`, `tests/`
- ZET: the user's integration tests, openziti/ziti-tunnel-sdk-c `tests/integration/*.go`

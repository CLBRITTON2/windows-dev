---
id: log-arguments-not-formatted-strings
applies_to:
  - all code
territory:
  - "**/*.go"
  - "**/*.cs"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.py"
  - "**/*.rs"
---

## statement

In a file whose log calls pass values as named fields, a new log call passes its values the same way. It does not
build the message first with string interpolation, concatenation or a format call.

## why

A named field is a property a reader can filter and query on. A value baked into a pre-built message is only text,
and the call reads differently from its neighbors.

## discrimination

Flag a new or changed log call that builds its message with C# `$"..."`, a JS template literal, a Python f-string,
`+`, `string.Format`, `fmt.Sprintf`, `%` or `.format()`, in a file whose other log calls pass named fields: Go `slog`
attributes, logrus `WithField`, NLog or Serilog `{Name}` templates, Rust `tracing` fields, or a JS or Python logger
called with a fields object or `extra`.

## example

Bad, in a file whose calls use `slog` attributes:

```go
slog.Error(fmt.Sprintf("SetProxy %s could not reach ziti-edge-tunnel", proxyUrl), "error", err)
```

Good:

```go
slog.Error("SetProxy could not reach ziti-edge-tunnel", "proxyUrl", proxyUrl, "error", err)
```

## boundary

Do not flag an interpolated or formatted message in a file whose log calls do not use named fields: C# `$"..."`
beside other `$"..."` or positional `{0}` calls, Go `Infof`, `t.Logf` in tests, plain `console.log`. Do not ask to
convert a file's existing calls, or to switch a file to named fields. C logging macros such as `ZITI_LOG` are
printf-style by design and are out of this rule's territory.

---
id: no-bulk
applies_to:
  - scripts
territory:
  - "**/*.ps1"
  - "**/*.sh"
  - "**/*.mjs"
  - "**/*.py"
  - "**/Makefile"
  - ".github/workflows/*.yml"
---

## statement

Scripts print only what a reader needs: errors and results. No banners, separators, step headers or decorative output.

## why

Decoration buries the line that matters in a log and adds code that does nothing.

## discrimination

Flag:

- banner or separator lines (`====>`, `-----`, `#####`, boxes)
- echo lines that announce each step ("Starting build...", "Done!")
- color or emoji added only for decoration

## example

Bad:

```powershell
Write-Host "==== Building ===="
dotnet build
Write-Host "==== Done ===="
```

Good:

```powershell
dotnet build
```

## boundary

Do not flag output a CI system parses (`::group::`, `##[error]`) or a final line that reports a result.

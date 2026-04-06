# ── Prompt ──
function prompt {
    $time = Get-Date -Format "HH:mm"
    $user = $env:USERNAME
    $path = $(Get-Location).Path
    "┌[$time]-[$user]-[$path]`n└─> "
}

# ── PSReadLine ──
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -Colors @{
    Command            = "`e[38;2;235;188;186m"   # Rose
    Comment            = "`e[38;2;110;106;134m"   # Muted
    ContinuationPrompt = "`e[38;2;110;106;134m"
    Default            = "`e[38;2;224;222;244m"   # Text
    Emphasis           = "`e[38;2;246;193;119m"   # Gold
    Error              = "`e[38;2;235;111;146m"   # Love
    InlinePrediction   = "`e[38;2;110;106;134m"   # Muted
    Keyword            = "`e[38;2;49;116;143m"    # Pine
    Member             = "`e[38;2;156;207;216m"   # Foam
    Number             = "`e[38;2;246;193;119m"   # Gold
    Operator           = "`e[38;2;49;116;143m"    # Pine
    Parameter          = "`e[38;2;196;167;231m"   # Iris
    Selection          = "`e[48;2;64;61;82m"      # Highlight High
    String             = "`e[38;2;246;193;119m"   # Gold
    Type               = "`e[38;2;156;207;216m"   # Foam
    Variable           = "`e[38;2;196;167;231m"   # Iris
}

# ── fzf ──
$env:PATH += ";C:\Users\chris\AppData\Local\Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe"
$env:PATH += ";C:\Users\chris\AppData\Local\Microsoft\WinGet\Packages\eza-community.eza_Microsoft.Winget.Source_8wekyb3d8bbwe"
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'

# ── PSStyle (PS 7.2+) ──
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory    = "`e[38;2;196;167;231m"   # Iris
    $PSStyle.FileInfo.SymbolicLink = "`e[38;2;156;207;216m"   # Foam
    $PSStyle.FileInfo.Executable   = "`e[38;2;235;188;186m"   # Rose
    $PSStyle.FileInfo.Extension.Clear()
    $PSStyle.FileInfo.Extension.Add(".ps1",  "`e[38;2;235;188;186m")
    $PSStyle.FileInfo.Extension.Add(".psm1", "`e[38;2;235;188;186m")
    $PSStyle.FileInfo.Extension.Add(".psd1", "`e[38;2;235;188;186m")
    $PSStyle.FileInfo.Extension.Add(".json", "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".xml",  "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".yaml", "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".yml",  "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".toml", "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".md",   "`e[38;2;156;207;216m")
    $PSStyle.FileInfo.Extension.Add(".txt",  "`e[38;2;224;222;244m")
    $PSStyle.FileInfo.Extension.Add(".log",  "`e[38;2;110;106;134m")
    $PSStyle.FileInfo.Extension.Add(".git",  "`e[38;2;235;111;146m")
    $PSStyle.FileInfo.Extension.Add(".go",   "`e[38;2;156;207;216m")
    $PSStyle.FileInfo.Extension.Add(".py",   "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".cs",   "`e[38;2;49;116;143m")
    $PSStyle.FileInfo.Extension.Add(".cpp",  "`e[38;2;49;116;143m")
    $PSStyle.FileInfo.Extension.Add(".h",    "`e[38;2;49;116;143m")
    $PSStyle.FileInfo.Extension.Add(".js",   "`e[38;2;246;193;119m")
    $PSStyle.FileInfo.Extension.Add(".ts",   "`e[38;2;156;207;216m")
    $PSStyle.FileInfo.Extension.Add(".lua",  "`e[38;2;196;167;231m")
    $PSStyle.FileInfo.Extension.Add(".zip",  "`e[38;2;235;111;146m")
    $PSStyle.FileInfo.Extension.Add(".tar",  "`e[38;2;235;111;146m")
    $PSStyle.FileInfo.Extension.Add(".gz",   "`e[38;2;235;111;146m")
    $PSStyle.FileInfo.Extension.Add(".exe",  "`e[38;2;235;188;186m")
    $PSStyle.FileInfo.Extension.Add(".dll",  "`e[38;2;110;106;134m")
    $PSStyle.Formatting.TableHeader  = "`e[38;2;110;106;134m"
    $PSStyle.Formatting.FormatAccent = "`e[38;2;196;167;231m"
    $PSStyle.Formatting.ErrorAccent  = "`e[38;2;235;111;146m"
    $PSStyle.Formatting.Error        = "`e[38;2;235;111;146m"
    $PSStyle.Formatting.Warning      = "`e[38;2;246;193;119m"
    $PSStyle.Formatting.Verbose      = "`e[38;2;110;106;134m"
    $PSStyle.Formatting.Debug        = "`e[38;2;110;106;134m"
    $PSStyle.Progress.View           = "Classic"
    $PSStyle.Progress.Style          = "`e[38;2;196;167;231m"
}

# ── Aliases ──
Set-Alias -Name c     -Value Clear-Host
Set-Alias -Name which -Value Get-Command

Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ll -Force -ErrorAction SilentlyContinue

function ls  { eza -a  --icons=always @args }
function ll  { eza -al --icons=always @args }
function lt  { eza -a  --tree --level=1 --icons=always @args }
function ..  { Set-Location .. }
function ... { Set-Location ..\.. }


# Windows dev environment

- Bar: https://github.com/glzr-io/zebar
- Window manager: https://github.com/glzr-io/glazewm
- Mem reduct: https://github.com/henrypp/memreduct
- Hide Windows taskbar: https://github.com/amnweb/thide
- App launcher: https://learn.microsoft.com/en-us/windows/powertoys/

Main VSCode extensions are Vim and Rose Pine  
WezTerm uses my lazyvim config https://github.com/CLBRITTON2/lazyvim-config and .zshrc from https://github.com/CLBRITTON2/dots in WSL  
Notepad++ is just a rose pine theme  
Visual Studio 2022 extensions are Rose Pine and VsVim 2022
- ctrl c, ctrl f, ctrl v handled by VS all others handled by VsVim

## Claude Code context

[`agents/context.md`](agents/context.md) holds my working rules: responses, code style, error handling,
workflow, git, shell, and environment. It loads at the start of every Claude Code session through an
`@`-import in `~/.claude/CLAUDE.md`, so this repo is the single source of truth.

`agents/hooks/pre-tool-use-hook.ps1` enforces the bash rules from `context.md` as a Claude Code PreToolUse
hook.

### Setup on a new machine

`~/.claude/CLAUDE.md` and `~/.claude/settings.json` are not in this repo. Recreate them so they point at
this repo. Replace `<REPO>` with wherever the repo lives.

`~/.claude/CLAUDE.md`:

```
# Global Rules

@<REPO>/agents/context.md
```

`~/.claude/settings.json` (the hook wiring, plus deny git mutations so the agent asks before changing the
repo):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "pwsh -NoProfile -File <REPO>/agents/hooks/pre-tool-use-hook.ps1", "timeout": 5 }
        ]
      }
    ]
  },
  "permissions": {
    "deny": [
      "Bash(git commit*)", "Bash(git push*)", "Bash(git checkout*)", "Bash(git reset*)",
      "Bash(git restore*)", "Bash(git clean*)", "Bash(git rebase*)", "Bash(git branch -d*)",
      "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)", "Read(~/.aws/**)", "Read(~/.encrypted/**)"
    ]
  }
}
```
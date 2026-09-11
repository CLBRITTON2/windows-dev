# Windows dev environment

- Bar: https://github.com/glzr-io/zebar
- Window manager: https://github.com/glzr-io/glazewm
- Mem reduct: https://github.com/henrypp/memreduct
- Hide Windows taskbar: https://github.com/amnweb/thide
- App launcher: https://learn.microsoft.com/en-us/windows/powertoys/

WezTerm uses my lazyvim config https://github.com/CLBRITTON2/lazyvim-config and .zshrc from https://github.com/CLBRITTON2/dots in WSL  
Visual Studio 2022 extensions: VsVim 2022
- ctrl c, ctrl f, ctrl v handled by VS all others handled by VsVim

## Claude Code context

[`claude/context.md`](claude/context.md) holds working rules: responses, code style, error handling,
workflow, git, shell, and environment. `~/.claude/CLAUDE.md` is a symlink to it, so this repo is the single
source of truth.

`claude/hooks/pre-tool-use-hook.ps1` enforces the bash rules from `context.md` as a Claude Code PreToolUse
hook.

### Setup on a new machine

Run [`install.ps1`](install.ps1) from an elevated pwsh 7 shell. Anything already at a link target that is
not itself a link is moved to `~/.dotfiles-backup/<timestamp>/`. It links `~/.claude/CLAUDE.md`,
`~/.claude/settings.json`, `~/.claude/agents`, `~/.claude/output-styles`, and the skills at `claude/` in this
repo, along with the other app configs.

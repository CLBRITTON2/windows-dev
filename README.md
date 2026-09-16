# Windows dev environment

- Bar: https://github.com/glzr-io/zebar
- Window manager: https://github.com/glzr-io/glazewm
- Mem reduct: https://github.com/henrypp/memreduct
- Hide Windows taskbar: https://github.com/amnweb/thide
- App launcher: https://learn.microsoft.com/en-us/windows/powertoys/

WezTerm uses my lazyvim config https://github.com/CLBRITTON2/lazyvim-config and .zshrc from
https://github.com/CLBRITTON2/dots in WSL  
Visual Studio 2022 extensions: VsVim 2022
- ctrl c, ctrl f, ctrl v handled by VS all others handled by VsVim

## Claude Code context

[`claude/context.md`](claude/context.md) holds working rules: responses, code style, error handling,
workflow, git, shell, and environment. `~/.claude/CLAUDE.md` is a symlink to it, so this repo is the single
source of truth.

### Claude Code runs as its own Windows account

Claude Code runs as `claude`, a standard account in `Users` with no administrator rights, created by
[`scripts/setup-agent-account.ps1`](scripts/setup-agent-account.ps1). Its access:

- Modify on `~/dev`, the only grant it holds in the owner's profile. Everything else there, `.ssh`, `.aws`,
  `.claude`, browser data, is unreadable, and the profile cannot be listed.
- Write denied on every `.git` under `~/dev`, so add, commit, checkout, and every other ref or index mutation
  fail for the account.
- Write denied on the dotfiles this repo links into the owner's home and on `install.ps1`, since those execute
  as the owner or elevated.
- Its own profile, holding its keys, config, and scratch files.

The `claude` function in the PowerShell profile starts a session as that account. `~/.local/bin/claude` runs
uncontained as whoever invokes it.

`claude/hooks/pre-tool-use-hook.ps1` enforces the bash rules from `context.md` as a Claude Code PreToolUse
hook. It is a guardrail against habits, not a boundary. The account above is the boundary.

### Setup on a new machine

Two scripts, both from an elevated pwsh 7 shell, both safe to rerun:

```powershell
# Setup configs
.\install.ps1
# Setup agent account
.\scripts\setup-agent-account.ps1
```

Anything already at a link target that is not itself a link is moved to `~/.dotfiles-backup/<timestamp>/`.
Both scripts share the `Link` function in [`scripts/dotfile-link.ps1`](scripts/dotfile-link.ps1).

`setup-agent-account.ps1` creates the account, applies the ACLs, then runs
[`scripts/agent-bootstrap.ps1`](scripts/agent-bootstrap.ps1) as the account through `runas`, which junctions
the account's `~/dev` onto the owner's, puts `~/.local/bin` on its persistent PATH (the Claude Code installer
only sets it for its own session), marks the repos safe for git, and installs Claude Code. Back in the elevated
shell it links the account's profile, WezTerm config, and `~/.claude` entries, since the account has no
privilege to create symlinks.

`runas` saves the account password once, which the `claude` function relies on later. Two interactive steps are
left: `/login` in an agent session, and `gh auth login` with a read-only PAT.

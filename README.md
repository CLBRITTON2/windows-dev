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
hook. It is a guardrail against habits, not a boundary. The boundary is a separate unprivileged Windows account
that Claude Code runs under: [`scripts/setup-agent-account.ps1`](scripts/setup-agent-account.ps1) creates it,
grants it `~/dev` only, and denies write on every repo's `.git`. `claude` in the PowerShell profile launches a
session as that account. The uncontained binary is still reachable as `~/.local/bin/claude`.

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
its `~/dev` onto yours, puts `~/.local/bin` on its persistent PATH (the Claude Code installer only sets it for
its own session), marks the repos safe for git, and installs Claude Code. Back in the elevated shell it links
the account's profile, WezTerm config, and `~/.claude` entries, because the account has no privilege to create
symlinks itself.

`runas` asks for the account password once and saves it, which is what the `claude` function in the
PowerShell profile relies on later. Two interactive steps are left over: `/login` in an agent session, and
`gh auth login` with a read-only PAT.

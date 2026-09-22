# Windows dev environment

My Windows setup: a tiling window manager, a custom status bar, terminal and editor configs, and a sandboxed
Claude Code.

| What | Tool |
| --- | --- |
| Window manager | [GlazeWM](https://github.com/glzr-io/glazewm) |
| Status bar | [Zebar](https://github.com/glzr-io/zebar) |
| Terminal | [WezTerm](https://wezfurlong.org/wezterm/) with [lazyvim](https://github.com/CLBRITTON2/lazyvim-config) and [.zshrc](https://github.com/CLBRITTON2/dots) in WSL |
| App launcher | [PowerToys](https://learn.microsoft.com/en-us/windows/powertoys/) |
| Hide the taskbar | [thide](https://github.com/amnweb/thide) |
| Free up RAM | [Mem Reduct](https://github.com/henrypp/memreduct) |
| Visual Studio 2022 | VsVim 2022 (VS keeps ctrl+c, ctrl+f, ctrl+v, VsVim gets everything else) |

## New machine

Open Windows PowerShell as administrator and run, picking your layout:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/CLBRITTON2/windows-dev/master/bootstrap.ps1))) -Layout Laptop
```

[`bootstrap.ps1`](bootstrap.ps1) installs git, clones this repo to `~\dev\windows-dev`, installs every app in
[`winget/packages.json`](winget/packages.json), links the configs, and creates the Claude Code account. It is
safe to rerun.

Then by hand:

- Install [Ziti Desktop Edge](https://github.com/openziti/desktop-edge-win/releases) and
  [thide](https://github.com/amnweb/thide/releases) (not on winget).
- Reboot if WSL was just installed.
- Run `claude`, then `/login`.
- Run `gh auth login` with a read-only PAT.

## Layouts

The layout picks which GlazeWM config gets linked:

| Layout | Keyboard | Monitors | Config |
| --- | --- | --- | --- |
| `Laptop` | builtin, lwin | 1 | [`config_laptop.yaml`](glazewm/config_laptop.yaml) |
| `Kinesis` | Kinesis, rwin | 1 | [`config_kinesis.yaml`](glazewm/config_kinesis.yaml) |
| `Desktop` | rwin | 2 | [`config_desktop.yaml`](glazewm/config_desktop.yaml) |

To switch layouts, run this from an elevated pwsh 7 shell in the repo:

```powershell
.\setup-configs.ps1 -Layout Kinesis
```

Anything already at a link target gets moved to `~/.dotfiles-backup/<timestamp>/` first.

## Claude Code

Claude Code runs as its own standard Windows account, `claude`. It can edit `~/dev` and nothing else in my
profile, and it cannot commit, push, or change the scripts and configs that run as me. The `claude` command in
the PowerShell profile starts a session as that account. Details are in
[`scripts/setup-agent-account.ps1`](scripts/setup-agent-account.ps1).

- [`claude/context.md`](claude/context.md) holds the working rules. `~/.claude/CLAUDE.md` links to it.
- [`claude/hooks/pre-tool-use-hook.ps1`](claude/hooks/pre-tool-use-hook.ps1) catches bad shell habits. It is a
  guardrail, not a security boundary. The account is the boundary.

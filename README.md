# Windows dev environment

My Windows setup: a tiling window manager, terminal and editor configs, and a sandboxed Claude Code.

| What | Tool |
| --- | --- |
| Window manager | [GlazeWM](https://github.com/glzr-io/glazewm) |
| Status bar | [intarsia](https://github.com/CLBRITTON2/intarsia), configured in [`intarsia/`](intarsia/) |
| Terminal | [WezTerm](https://wezfurlong.org/wezterm/) into WSL, see [WSL configs](#wsl-configs) |
| App launcher | [PowerToys](https://learn.microsoft.com/en-us/windows/powertoys/) |
| Hide the taskbar | [thide](https://github.com/amnweb/thide) |
| Visual Studio 2022 | VsVim 2022 (VS keeps ctrl+c, ctrl+f, ctrl+v, VsVim gets everything else) |

### WSL configs

WSL uses my [lazyvim config](https://github.com/CLBRITTON2/lazyvim-config) and the `.zshrc` from
[dots](https://github.com/CLBRITTON2/dots).

## New machine

Open Windows PowerShell as administrator and run, picking your layout:

```powershell
& ([scriptblock]::Create((irm -UseBasicParsing https://raw.githubusercontent.com/CLBRITTON2/windows-dev/master/bootstrap.ps1))) -Layout Single
```

[`bootstrap.ps1`](bootstrap.ps1) installs git, clones this repo to `~\dev\windows-dev`, then runs the three setup
scripts in order. Each one is safe to rerun on its own:

- [`setup-packages.ps1`](setup-packages.ps1) (elevated, Windows PowerShell or pwsh): every app in
  [`winget/packages.json`](winget/packages.json), PSFzf, vcpkg, the VS Code extensions, Developer Mode, and Win+L
  off.
- [`setup-configs.ps1`](setup-configs.ps1) `-Layout` (pwsh): links every config and the GlazeWM layout.
- [`setup-claude.ps1`](setup-claude.ps1) (elevated pwsh): the Claude Code account, its permissions, and its
  `~/.claude`.

Then by hand:

- Install [Ziti Desktop Edge](https://github.com/openziti/desktop-edge-win/releases) and
  [thide](https://github.com/amnweb/thide/releases) (not on winget).
- Install the VsVim 2022 extension from Visual Studio's Extensions menu.
- Reboot if WSL was just installed.
- Run `claude`, then `/login`.
- Run `gh auth login` with a read-only PAT.

## Layouts

The layout picks which GlazeWM config gets linked. Both bind every shortcut on lwin and rwin, and a lone tap of
either Win key opens Start.

| Layout | Monitors | Config |
| --- | --- | --- |
| `Single` | 1 | [`config_single.yaml`](glazewm/config_single.yaml) |
| `Dual` | 2 | [`config_dual.yaml`](glazewm/config_dual.yaml) |

To switch layouts, click `Single` or `Dual` on the bar, or rerun the config script:

```powershell
.\setup-configs.ps1 -Layout Dual
```

Both need Developer Mode (turned on by `setup-packages.ps1`) or an elevated shell to create the symlinks.

Anything already at a link target gets moved to `~/.dotfiles-backup/<timestamp>/` first.

## Claude Code

Claude Code runs as its own standard Windows account, `claude`. It can edit `~/dev` and nothing else in my
profile, and it cannot commit, push, or change the scripts and configs that run as me. The `claude` command in
the PowerShell profile starts a session as that account. Details are in
[`setup-claude.ps1`](setup-claude.ps1).

- [`claude/context.md`](claude/context.md) holds the working rules. `~/.claude/CLAUDE.md` links to it.
- [`claude/hooks/pre-tool-use-hook.ps1`](claude/hooks/pre-tool-use-hook.ps1) catches bad shell habits. It is a
  guardrail, not a security boundary. The account is the boundary.

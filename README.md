# Windows dev environment

My Windows setup: a tiling window manager, terminal and editor configs, and a sandboxed Claude Code.

| What | Tool |
| --- | --- |
| Window manager | [GlazeWM](https://github.com/glzr-io/glazewm) |
| Status bar | [intarsia](https://github.com/CLBRITTON2/intarsia), configured in [`intarsia/`](intarsia/) |
| Terminal | Windows Terminal, [WezTerm](https://wezfurlong.org/wezterm/) for WSL, Claude Code and herdr |
| App launcher | [carronade](https://github.com/CLBRITTON2/carronade), configured in [`carronade/`](carronade/) |
| Session restore | [rallypoint](https://github.com/CLBRITTON2/rallypoint), started by the GlazeWM layouts |
| Agent multiplexer | [herdr](https://herdr.dev), with the [`herdr/focus-file`](herdr/focus-file/) plugin |
| Diff reviewer | perusal, configured in [`perusal/`](perusal/), started by `pfc` in the profile |
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

[`bootstrap.ps1`](bootstrap.ps1) installs git, clones this repo to `~\dev\windows-dev`, then runs the two setup
scripts in order. Each one is safe to rerun on its own:

- [`scripts/setup-packages.ps1`](scripts/setup-packages.ps1) (elevated, Windows PowerShell or pwsh): every app in
  [`winget/packages.json`](winget/packages.json), PSFzf, vcpkg, the MSYS2 compilers, the VS Code extensions, the
  latest carronade, rallypoint, and intarsia releases, Developer Mode, and the registry access
  `glazewm/winkey-fix.ahk` needs to hand Win+L to GlazeWM.
- [`scripts/setup-configs.ps1`](scripts/setup-configs.ps1) `-Layout` (pwsh): links every config and the GlazeWM
  layout.

Then by hand:

- Install [Ziti Desktop Edge](https://github.com/openziti/desktop-edge-win/releases) and
  [thide](https://github.com/amnweb/thide/releases) (not on winget).
- Install the VsVim 2022 extension from Visual Studio's Extensions menu.
- Reboot, then install a WSL distro with `wsl --install Ubuntu`.
- Copy perusal to `~\dev\perusal` (it has no remote) and run `go -C ~\dev\perusal install ./cmd/perusal`.
- Build the agent VM with [`scripts/new-agent-vm.ps1`](scripts/new-agent-vm.ps1), then run `claude` there and
  `/login`.

## Layouts

The layout picks which GlazeWM config gets linked. Both bind every shortcut on lwin and rwin, and a lone tap of
either Win key opens Start.

| Layout | Monitors | Config |
| --- | --- | --- |
| `Single` | 1 | [`config_single.yaml`](glazewm/config_single.yaml) |
| `Dual` | 2 | [`config_dual.yaml`](glazewm/config_dual.yaml) |

To switch layouts, click `Single` or `Dual` on the bar, or rerun the config script:

```powershell
.\scripts\setup-configs.ps1 -Layout Dual
```

Both need Developer Mode (turned on by `scripts/setup-packages.ps1`) or an elevated shell to create the symlinks.

Anything already at a link target gets moved to `~/.dotfiles-backup/<timestamp>/` first.

## Claude Code

Claude Code runs as the account `claude` in a Hyper-V VM built by
[`scripts/new-agent-vm.ps1`](scripts/new-agent-vm.ps1). The VM reaches the internet but not the host, the LAN, or
my ziti services, and its `gh` token is read-only.

- [`claude/context.md`](claude/context.md) holds the working rules. `~/.claude/CLAUDE.md` links to it.
- [`claude/hooks/pre-tool-use-hook.ps1`](claude/hooks/pre-tool-use-hook.ps1) catches bad shell habits. It is a
  guardrail, not a security boundary. The VM is the boundary.
- [`claude/statusline.ps1`](claude/statusline.ps1) draws the status line.
- [`scripts/clean-agent.ps1`](scripts/clean-agent.ps1), run as the account, deletes the scratch folders of
  sessions idle for a week.

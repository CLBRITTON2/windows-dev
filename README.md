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

In Windows PowerShell as administrator, picking your layout:

```powershell
& ([scriptblock]::Create((irm -UseBasicParsing https://raw.githubusercontent.com/CLBRITTON2/windows-dev/master/bootstrap.ps1))) -Layout Single
```

Then by hand:

- Install [Ziti Desktop Edge](https://github.com/openziti/desktop-edge-win/releases) and
  [thide](https://github.com/amnweb/thide/releases) (not on winget).
- Install the VsVim 2022 extension from Visual Studio's Extensions menu.
- Reboot, then install a WSL distro with `wsl --install Ubuntu`.
- Copy perusal to `~\dev\perusal` (it has no remote) and run `go -C ~\dev\perusal install ./cmd/perusal`.
- Set up the agent VM, below.

[`bootstrap.ps1`](bootstrap.ps1) installs git, clones this repo to `~\dev\windows-dev`, adds the runtime checkout
`~\.windows-dev`, then runs these from there, each safe to rerun on its own:

- [`scripts/host/setup-packages.ps1`](scripts/host/setup-packages.ps1) (elevated, Windows PowerShell or pwsh): every
  app in [`winget/packages.json`](winget/packages.json), PSFzf, vcpkg, the MSYS2 compilers, the VS Code extensions,
  the latest carronade, rallypoint, and intarsia releases, Developer Mode, and the registry access
  `glazewm/winkey-fix.ahk` needs to hand Win+L to GlazeWM.
- [`scripts/host/setup-configs.ps1`](scripts/host/setup-configs.ps1) `-Layout` (pwsh): links every config and the
  GlazeWM layout.

## Claude Code

Claude Code runs as the account `claude` in a Hyper-V VM, the agent VM. The VM reaches the internet but not the host,
the LAN, or my ziti services, and its `gh` token is read-only.

### Set up the agent VM

Needs:

- The Windows 11 Enterprise evaluation ISO (64-bit) from the
  [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise), saved in
  your profile outside `~\dev`, for example `~\Downloads`.
- An ssh key pair, for example from `ssh-keygen -t ed25519 -f "$HOME\.ssh\claude-vm"`.
- A new fine-grained read-only [GitHub token](https://github.com/settings/personal-access-tokens/new), which the
  script asks for first.

In pwsh as administrator (about 35 minutes):

```powershell
& "$HOME\.windows-dev\scripts\host\new-agent-vm.ps1" -InstallIso "$HOME\Downloads\windows-eval.iso" -AuthorizedKeyPath "$HOME\.ssh\claude-vm.pub" -VmName claude-vm -PersonalSetupPath "$HOME\.windows-dev\scripts\agent-vm\agent-vm-personal-setup.ps1"
```

Then run `herdr`, and `claude` in a pane once to log in. The evaluation runs out after 90 days: rebuild with a new
`-VmName`, or delete the old VM and its `C:\ProgramData\<VmName>` folder first. Without `-PersonalSetupPath`, the VM
gets only git, gh, pwsh, Claude Code and herdr ([`docs/agent-vm.md`](docs/agent-vm.md)).

### Claude Code config

- [`claude/context.md`](claude/context.md) holds the working rules. `~/.claude/CLAUDE.md` links to it.
- [`claude/hooks/pre-tool-use-hook.ps1`](claude/hooks/pre-tool-use-hook.ps1) catches bad shell habits. It is a
  guardrail, not a security boundary. The VM is the boundary.
- [`claude/statusline.ps1`](claude/statusline.ps1) draws the status line.
- [`scripts/agent-vm/clean-agent.ps1`](scripts/agent-vm/clean-agent.ps1), run as the account, deletes the scratch
  folders of sessions idle for a week.

## Layouts

The layout picks which GlazeWM config gets linked. Both bind every shortcut on lwin and rwin, and a lone tap of
either Win key opens Start.

| Layout | Monitors | Config |
| --- | --- | --- |
| `Single` | 1 | [`config_single.yaml`](glazewm/config_single.yaml) |
| `Dual` | 2 | [`config_dual.yaml`](glazewm/config_dual.yaml) |

To switch layouts, click `Single` or `Dual` on the bar, or rerun the config script:

```powershell
~\.windows-dev\scripts\host\setup-configs.ps1 -Layout Dual
```

Both need Developer Mode (turned on by `scripts/host/setup-packages.ps1`) or an elevated shell to create the symlinks.

Anything already at a link target gets moved to `~/.dotfiles-backup/<timestamp>/` first.

## Where configs live

Every config lives in this repo. Edit them in `~\dev\windows-dev`, and they take effect once committed:
[`setup-configs.ps1`](scripts/host/setup-configs.ps1) links them from `~\.windows-dev`, a checkout that a git hook
keeps on `master`. Nothing on the laptop runs from `~\dev`, since perusal writes the agent's commits there unreviewed.
[`scripts/host`](scripts/host) runs on the laptop, [`scripts/agent-vm`](scripts/agent-vm) inside the VM.

# Windows dev environment

My Windows setup: a tiling window manager, terminal and editor configs, and a sandboxed Claude Code.

| Role | Tool |
| --- | --- |
| Window manager | [GlazeWM](https://github.com/glzr-io/glazewm) |
| Status bar | [intarsia](https://github.com/CLBRITTON2/intarsia) |
| App launcher | [carronade](https://github.com/CLBRITTON2/carronade) |
| Session restore | [rallypoint](https://github.com/CLBRITTON2/rallypoint) |
| Taskbar hider | [thide](https://github.com/amnweb/thide) |
| Terminal for WSL, Claude Code and herdr | [WezTerm](https://wezfurlong.org/wezterm/) |
| Agent multiplexer | [herdr](https://herdr.dev) |
| Git client that can follow Claude | [perusal](https://github.com/CLBRITTON2/perusal) |

## New machine

In Windows PowerShell as administrator, picking your layout:

```powershell
& ([scriptblock]::Create((irm -UseBasicParsing https://raw.githubusercontent.com/CLBRITTON2/windows-dev/main/bootstrap.ps1))) -Layout Single
```

Then by hand:

- Install [Ziti Desktop Edge](https://github.com/openziti/desktop-edge-win/releases).
- Install the VsVim 2022 extension from Visual Studio's Extensions menu.
- Reboot, then install a WSL distro with `wsl --install Ubuntu`. In it, run
  `bash /mnt/c/Users/<you>/.windows-dev/wsl/setup.sh` ([`wsl/setup.sh`](wsl/setup.sh)): the packages zsh and nvim
  need, [`wsl/zshrc`](wsl/zshrc) linked to `~/.zshrc`, and the nvim config cloned from
  [lazyvim-config](https://github.com/CLBRITTON2/lazyvim-config).
- Install perusal with `go install github.com/CLBRITTON2/perusal/cmd/perusal@latest`.
- Set up the agent VM, below.

[`bootstrap.ps1`](bootstrap.ps1) installs git, clones this repo to `~\dev\windows-dev`, adds the runtime checkout
`~\.windows-dev`, then runs these from there, each safe to rerun on its own:

- [`scripts/host/setup-packages.ps1`](scripts/host/setup-packages.ps1) (elevated, Windows PowerShell or pwsh): every
  app in [`winget/packages.json`](winget/packages.json), PSFzf, vcpkg, the MSYS2 compilers, the VS Code extensions,
  the latest carronade, rallypoint, intarsia and [thide](https://github.com/amnweb/thide) releases, Developer Mode,
  the registry access `glazewm/winkey-fix.ahk` needs to hand Win+L to GlazeWM, and a Startup shortcut that starts
  GlazeWM at logon.
- [`scripts/host/setup-configs.ps1`](scripts/host/setup-configs.ps1) `-Layout` (pwsh): links every config and the
  GlazeWM layout.

## Claude Code

Claude Code runs as the account `claude` in a Hyper-V VM, the agent VM. The VM reaches the internet but not the host,
the LAN, or my ziti services, and its `gh` token is read-only.

### Set up the agent VM

Needs:

- Windows with Hyper-V (Pro or Enterprise), PowerShell 7 and git.
- The Windows 11 Enterprise evaluation ISO (64-bit) from the
  [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise), saved in
  your profile outside `~\dev`, for example `~\Downloads`.
- An ssh key pair, for example from `ssh-keygen -t ed25519 -f "$HOME\.ssh\claude-vm"`.
- A new fine-grained read-only [GitHub token](https://github.com/settings/personal-access-tokens/new), which the
  script asks for first.

If you skipped the bootstrap, clone this repo first with `git clone https://github.com/CLBRITTON2/windows-dev.git`
and run the script from your clone in place of `~\.windows-dev`.

In pwsh as administrator (about 35 minutes), with your own ISO and public key paths:

```powershell
& "$HOME\.windows-dev\scripts\host\new-agent-vm.ps1" -InstallIso <path\to\windows-eval.iso> -AuthorizedKeyPath <path\to\key.pub> -VmName <vm-name>
```

The script adds a `Host <vm-name>` entry to `~\.ssh\config`. Then `ssh <vm-name>`, run `herdr`, and `claude` in a pane
once to log in. The evaluation runs out after 90 days: rebuild with a new `-VmName`, or delete the old VM and its
`C:\ProgramData\<VmName>` folder first. The VM gets only git, gh, pwsh, Claude Code and herdr.
`-PersonalSetupPath <script>` runs a setup script of your own in the VM after that. Mine is
[`scripts/agent-vm/agent-vm-personal-setup.ps1`](scripts/agent-vm/agent-vm-personal-setup.ps1).

### Claude Code config

- [`claude/context.md`](claude/context.md) holds the working rules. `~/.claude/CLAUDE.md` links to it.
- [`claude/hooks/pre-tool-use-hook.ps1`](claude/hooks/pre-tool-use-hook.ps1) catches bad shell habits. It is a
  guardrail, not a security boundary. The VM is the boundary.
- [`claude/statusline.ps1`](claude/statusline.ps1) draws the status line.
- [`terminus/canon`](terminus/canon) holds the code rules
  [terminus](https://github.com/michaelquigley/terminus) reviews against, one file per rule.
  [`scripts/sync-rubrics.ps1`](scripts/sync-rubrics.ps1) writes a rubric listing all of them for each folder under
  `terminus/canon/projects/`, which stays out of git.
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
keeps on `main`. Nothing on the laptop runs from `~\dev`, since perusal writes the agent's commits there unreviewed.
[`scripts/host`](scripts/host) runs on the laptop, [`scripts/agent-vm`](scripts/agent-vm) inside the VM.

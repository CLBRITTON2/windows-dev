# Set up a Claude Code sandbox VM

Needs a version of Windows with Hyper-V, like Windows 11 Pro or Enterprise, plus PowerShell 7 and git.

You need:

- A Windows evaluation ISO, from the [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter).
- An ssh key pair.
- A read-only [GitHub token](https://github.com/settings/personal-access-tokens/new), which the script asks for.
- A name for the VM. Its disk and files go in `C:\ProgramData\<name>`.

Example run, in PowerShell 7 as administrator:

```powershell
ssh-keygen -t ed25519 -f "$HOME\.ssh\claude-vm"
git clone https://github.com/CLBRITTON2/windows-dev.git "$HOME\windows-dev"
& "$HOME\windows-dev\scripts\host\new-agent-vm.ps1" -InstallIso "$HOME\Downloads\windows-eval.iso" -AuthorizedKeyPath "$HOME\.ssh\claude-vm.pub" -VmName claude-vm
ssh claude-vm
claude
```

#!/usr/bin/env bash
# Sets up WSL Ubuntu for zsh and nvim: apt packages, the latest neovim, Go and tree-sitter CLI, ~/.zshrc linked to
# this folder, ~/winhome linked to the Windows home, the nvim config cloned, zsh as login shell. Run inside WSL as
# your WSL user, from the runtime checkout: bash /mnt/c/Users/<you>/.windows-dev/wsl/setup.sh. Safe to rerun.
set -euo pipefail

wsl_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
windows_home="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")"
if [[ ! -d "$windows_home" ]]; then
    echo "Windows home '$windows_home' from cmd.exe %USERPROFILE% is not a directory. Is WSL interop on?" >&2
    exit 1
fi

# perusal writes the agent's commits into ~\dev unreviewed, and the linked ~/.zshrc runs whatever is there.
shopt -s nocasematch
if [[ "$wsl_dir" == "$windows_home/dev/"* ]]; then
    echo "Run setup.sh from the runtime checkout ~/.windows-dev (bootstrap.ps1 makes it), not $wsl_dir" >&2
    exit 1
fi
shopt -u nocasematch

download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' EXIT

echo "apt packages"
sudo apt-get update
# build-essential compiles treesitter parsers, unzip, npm and python3-venv let Mason install language servers.
sudo apt-get install -y zsh build-essential git curl unzip ripgrep fd-find fzf eza nodejs npm python3-venv

echo "neovim"
curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    -o "$download_dir/nvim.tar.gz"
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf "$download_dir/nvim.tar.gz"

go_version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n 1)"
if [[ "$(/usr/local/go/bin/go version 2>/dev/null)" == "go version $go_version "* ]]; then
    echo "$go_version already installed"
else
    echo "$go_version"
    curl -fsSL "https://go.dev/dl/$go_version.linux-amd64.tar.gz" -o "$download_dir/go.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$download_dir/go.tar.gz"
fi

# nvim-treesitter's main branch builds parsers with the tree-sitter CLI.
echo "tree-sitter CLI"
mkdir -p "$HOME/.local/bin"
curl -fsSL https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-x64.gz \
    | gunzip > "$HOME/.local/bin/tree-sitter"
chmod +x "$HOME/.local/bin/tree-sitter"

backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
link() {
    local target="$1"
    local source="$2"
    if [[ -L "$target" ]]; then
        rm "$target"
    elif [[ -e "$target" ]]; then
        mkdir -p "$backup_dir"
        mv "$target" "$backup_dir/"
        echo "Existing item moved to: $backup_dir/$(basename "$target")"
    fi
    ln -s "$source" "$target"
    echo "  Linked: $target"
}

echo "links"
link "$HOME/.zshrc" "$wsl_dir/zshrc"
link "$HOME/winhome" "$windows_home"

if [[ -d "$HOME/.config/nvim" ]]; then
    echo "~/.config/nvim exists, leaving it alone"
else
    git clone https://github.com/CLBRITTON2/lazyvim-config.git "$HOME/.config/nvim"
fi

zsh_path="$(command -v zsh)"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
fi

echo "Done. Open a new shell, then run nvim once to let lazy.nvim and Mason install."

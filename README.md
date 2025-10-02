## README.md for `dotfiles` repo:


# Dotfiles

Personal configuration files managed with GNU Stow.

## Quick Start

```bash
# Clone and bootstrap
git clone https://github.com/USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

## What This Does

1. Installs `stow` and other prerequisites
2. Backs up existing configs (`.bashrc.backup.YYYYMMDD`)
3. Symlinks configs to proper locations
4. Adds source line to `.bashrc` (preserves distro defaults)

## Structure

- `shell/` - Bash/sh configs (sources from `~/.config/bash/`)
- `nvim/` - Neovim configuration
- `kde/` - KDE Plasma settings
- `git/` - Git configuration
- `install/` - Distro-specific package lists

## Private Configs

Sensitive configs (SSH keys, tokens) are in a separate private repo:
```bash
git clone git@github.com:USERNAME/private-dots.git ~/private-dots
cd ~/private-dots && ./bootstrap.sh
```

## Updating

```bash
cd ~/dotfiles && git pull && ./bootstrap.sh
```

## Manual Setup

If you prefer not to use the bootstrap script:
```bash
sudo apt install stow  # or zypper/dnf
stow shell nvim kde git
echo '[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc' >> ~/.bashrc
```



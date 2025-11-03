# Dotfiles

Personal configuration files managed with GNU Stow.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run bootstrap
./bootstrap.sh
```

The bootstrap script will:
1. Install shell and nvim configs via GNU Stow
2. Configure `.bashrc` to source custom bash config
3. Optionally install KDE configs
4. Show you the packages to install for your OS

## Repository Structure

```
dotfiles/
├── shell/          # Bash configuration → ~/.config/bash/
├── nvim/           # Neovim (LazyVim) → ~/.config/nvim/
├── kde/            # KDE Plasma configs → ~/.config/
├── packages/       # Package lists (common, desktop, server)
├── templates/      # Service setup guides (syncthing, caddy, etc.)
├── scripts/        # Helper scripts (setup-kde.sh, install-blesh.sh)
├── lib/            # Reusable script libraries (backup.sh)
└── bootstrap.sh    # Simple installer
```

## Installing Packages

After running `bootstrap.sh`, install packages with your package manager.

**openSUSE:**
```bash
sudo zypper install git stow curl wget neovim tmux fzf ripgrep ...
# Copy full list from packages/common.txt + packages/desktop.txt
```

**Ubuntu:**
```bash
sudo apt install git stow curl wget neovim tmux fzf ripgrep ...
# Copy full list from packages/common.txt + packages/server.txt
```

**After package installation:**
```bash
# Install Rust toolchain
rustup install stable && rustup default stable

# Optional: Install ble.sh (bash enhancement)
./scripts/install-blesh.sh
```

## Profiles

Choose packages based on your use case:

- **Desktop** (`packages/desktop.txt`) - Full workstation with syncthing, rclone, KDE apps
- **Server** (`packages/server.txt`) - Headless development server

All profiles use `packages/common.txt` as a base.

## Service Setup

For additional services, see the `templates/` directory. Each has a README with manual setup instructions:

- **Syncthing** - File synchronization between devices
- **Rclone Gateway** - Sync gateway with cloud backup (Syncthing + Rclone + Google Drive)
- **Caddy** - HTTPS reverse proxy with automatic Let's Encrypt certificates
- **Headscale** - Self-hosted Tailscale control server for mesh VPN

These are **documentation only** - no automation. Follow the READMEs to set up manually.

## Private Dotfiles

Sensitive configs (SSH, git identity, secrets) live in a separate private repo:

```bash
git clone git@github.com:USERNAME/private-dots.git ~/private-dots
cd ~/private-dots
./bootstrap.sh
```

## Updating

```bash
cd ~/dotfiles
git pull
./bootstrap.sh  # Re-stow configs
```

## Manual Stow

If you prefer to stow manually:

```bash
# Install stow
sudo zypper install stow  # or: apt install stow

# Stow individual packages
cd ~/dotfiles
stow shell          # Install bash configs
stow nvim           # Install neovim configs
stow kde            # Install KDE configs
```

## Helper Libraries

The `lib/` directory contains reusable script functions:

- **backup.sh** - File backup utilities (`backup_file`, `backup_directory`, `restore_backup`, etc.)

Source these in your own scripts:
```bash
source ~/dotfiles/lib/backup.sh
backup_file ~/.config/important.conf
```

## Notes

- Configs are symlinked, not copied - edit files in `~/dotfiles/` to keep them in git
- Run `./bootstrap.sh` again if you add new stow packages
- See `templates/` READMEs for service-specific setup guides

# Dotfiles

Personal configuration files managed with GNU Stow, plus a bootstrapper for new machines.

## Quick Start

```bash
# Clone and bootstrap
git clone https://github.com/USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
just bootstrap          # or ./bootstrap.sh
```

Pass a profile to tailor packages and folders:

```bash
just bootstrap desktop   # default
just bootstrap server
just bootstrap gateway
```

## What Bootstrapping Does

1. Ensures GNU Stow & git are present.
2. Creates profile-specific folders (via `scripts/setup-folders.sh`).
3. Symlinks every directory marked with a `.stow` file.
4. Configures `~/.bashrc` to source the managed config.
5. Installs distro + profile package sets and optional tooling (Rust, Node helpers, etc.).
6. Runs setup extras (KDE tweaks, Rust toolchain, secrets hook).

Use `./bootstrap.sh --dry-run` for a safe preview.

## Repository Layout

- `shell/` – Bash configuration (`~/.config/bash`, `ble.sh`, fzf tweaks).
- `nvim/` – LazyVim-based Neovim setup.
- `kde/` – KDE Plasma preferences, bookmarks, and Konsole profiles.
- `scripts/` – Helper scripts (Syncthing, KDE, rustup, secrets).
- `install/` – Shared package lists plus distro installers and per-profile extras.
- `lib/` – Bootstrap helpers (`prereqs`, `stow`, `packages`).
- `Justfile` – Task runner for bootstrap, installs, and checks.

Sensitive material (SSH keys, tokens, etc.) lives in the separate private repo:

```bash
git clone git@github.com:USERNAME/private-dots.git ~/private-dots
cd ~/private-dots && ./bootstrap.sh
```

## Profiles & Packages

Profile lists live under `install/profiles/` and stack on top of `install/common.txt`.
The provided profiles are:

- `minimal` – lean environment (no extras).
- `desktop` – full workstation tooling, sync (default).
- `server` – placeholders for headless tooling.
- `gateway` – sync gateway helpers (Syncthing + rclone).

Adjust the lists or add new profile files as needed.

## Task Runner

Useful commands from the `Justfile`:

```bash
just                    # same as `just bootstrap`
just bootstrap server   # run bootstrap for a server
just install-packages ubuntu desktop
just check              # shellcheck + stow simulation + package audit
just check server       # run checks for a profile
```

## Updating

```bash
cd ~/dotfiles
git pull
just bootstrap
```

## Manual Stow

If you prefer to manage things manually:

```bash
sudo apt install stow  # or zypper/dnf
stow shell nvim kde
```

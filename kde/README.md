# KDE Plasma Configuration

KDE Plasma settings for Fedora and Ubuntu.

## Included Configs

Stable preference files that are safe to symlink:

### Desktop & Window Manager
- **kdeglobals** - Global KDE settings (theme, colors, fonts)
- **kwinrc** - KWin window manager settings
- **plasmarc** - Plasma desktop appearance

### Applications
- **konsolerc** - Konsole terminal settings
- **dolphinrc** - Dolphin file manager settings

## What's NOT Included

Machine-specific or volatile state files that KDE constantly rewrites:
- `plasma-org.kde.plasma.desktop-appletsrc` - Desktop widget/panel layout (session state)
- `plasmashellrc` - Panel geometry and state (session state)
- `user-places.xbel` - Dolphin bookmarks (changes as you use the system)
- `kwinoutputconfig.json` - Display configuration (hardware-specific)
- `kded5rc`, `kded6rc` - Daemon configs
- `plasma-localerc` - Locale settings
- Session/cache files

## Installation

These are installed automatically when you run:
```bash
cd ~/dotfiles && ./bootstrap.sh
# Answer 'y' when asked about KDE configs
```

Or manually:
```bash
cd ~/dotfiles
stow kde
```

## Updating Your Config

Since these files are symlinked, any changes you make in KDE System Settings are automatically reflected in the dotfiles repo. Just commit and push:

```bash
cd ~/dotfiles
git add kde/
git commit -m "Update KDE settings"
git push
```

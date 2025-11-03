# KDE Plasma Configuration

openSUSE Tumbleweed KDE Plasma settings.

## Included Configs

This captures the essential KDE configuration files:

### Desktop & Window Manager
- **kdeglobals** - Global KDE settings (theme, colors, fonts)
- **kwinrc** - KWin window manager settings
- **plasmarc** - Plasma desktop settings
- **plasmashellrc** - Plasma shell configuration
- **plasma-org.kde.plasma.desktop-appletsrc** - Desktop widgets and applets

### Applications
- **konsolerc** - Konsole terminal settings
- **dolphinrc** - Dolphin file manager settings

### User Data
- **user-places.xbel** - Dolphin bookmarks and places

## What's NOT Included

Machine-specific configs are excluded:
- `kwinoutputconfig.json` - Display configuration (screen layout, resolution)
- `kded5rc`, `kded6rc` - Daemon configs
- `plasma-localerc` - Locale settings
- Session/cache files
- kdenlive configs (separate application)

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

## Notes

- These configs are specific to openSUSE Tumbleweed with KDE Plasma 6
- Display settings are intentionally excluded (they're hardware-specific)
- Konsole profiles should be configured per-machine
- Changes to KDE settings are immediately reflected in git

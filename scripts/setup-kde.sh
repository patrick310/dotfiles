#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-kde.sh - KDE Plasma configuration

# Only run if KDE is detected
if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    echo "    Not running KDE, skipping KDE setup"
    exit 0
fi

echo "    Configuring KDE Plasma..."

# Set KDE defaults via kwriteconfig5 (if available)
configure_kde_defaults() {
    if ! command -v kwriteconfig5 &> /dev/null && ! command -v kwriteconfig6 &> /dev/null; then
        echo "      kwriteconfig not found, skipping runtime configuration"
        return
    fi

    local kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5)

    echo "      Setting KDE preferences..."

    # Global KDE settings
    $kwriteconfig --file kdeglobals --group KDE --key SingleClick false

    # Dolphin settings
    $kwriteconfig --file dolphinrc --group General --key ShowFullPath true
    $kwriteconfig --file dolphinrc --group General --key ShowSpaceInfo false

    # KWin window management
    $kwriteconfig --file kwinrc --group Windows --key FocusPolicy "FocusFollowsMouse"
    $kwriteconfig --file kwinrc --group Windows --key AutoRaise false
}

# Set keyboard shortcuts for window management
setup_kde_shortcuts() {
    if ! command -v kwriteconfig5 &> /dev/null && ! command -v kwriteconfig6 &> /dev/null; then
        return
    fi

    local kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5)

    echo "      Setting up keyboard shortcuts..."

    # Window tiling shortcuts
    $kwriteconfig --file kglobalshortcutsrc --group kwin \
        --key "Window Quick Tile Left" "Meta+Left,Meta+Left,Quick Tile Window to the Left"
    $kwriteconfig --file kglobalshortcutsrc --group kwin \
        --key "Window Quick Tile Right" "Meta+Right,Meta+Right,Quick Tile Window to the Right"
    $kwriteconfig --file kglobalshortcutsrc --group kwin \
        --key "Window Maximize" "Meta+Up,Meta+Up,Maximize Window"
}

# Install KWin scripts for tiling (optional)
install_kwin_scripts() {
    if [ -z "${INSTALL_KWIN_SCRIPTS:-}" ]; then
        echo "      Skipping KWin tiling scripts (set INSTALL_KWIN_SCRIPTS=1 to install)"
        return
    fi

    if ! command -v kpackagetool5 &> /dev/null && ! command -v kpackagetool6 &> /dev/null; then
        echo "      kpackagetool not found, cannot install scripts"
        return
    fi

    local kpackagetool=$(command -v kpackagetool6 || command -v kpackagetool5)

    echo "      Installing KWin tiling script (Polonium)..."
    local script_url="https://github.com/zeroxoneafour/polonium/releases/latest/download/polonium.kwinscript"

    if command -v wget &> /dev/null; then
        wget -q -O /tmp/polonium.kwinscript "$script_url"
        $kpackagetool --type=KWin/Script --install /tmp/polonium.kwinscript 2>/dev/null || \
            $kpackagetool --type=KWin/Script --upgrade /tmp/polonium.kwinscript 2>/dev/null
        rm -f /tmp/polonium.kwinscript
    fi
}

# Main execution
configure_kde_defaults
setup_kde_shortcuts
install_kwin_scripts

echo "      ✓ KDE configuration applied (restart Plasma for all changes)"
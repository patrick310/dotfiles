#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-kde.sh

# Only run if KDE is detected
if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    echo "Not running KDE, skipping KDE setup"
    exit 0
fi

# Create KDE bookmarks for Dolphin sidebar
setup_dolphin_bookmarks() {
    echo "Setting up Dolphin bookmarks..."
    
    # Dolphin places file
    cat > ~/.local/share/user-places.xbel << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:kdepriv="http://www.kde.org/kdepriv">
 <bookmark href="file:///home/$USER/code">
  <title>Code</title>
  <info>
   <metadata owner="http://freedesktop.org">
    <bookmark:icon name="folder-development"/>
   </metadata>
  </info>
 </bookmark>
 <bookmark href="file:///home/$USER/code/spikes">
  <title>Spikes</title>
 </bookmark>
</xbel>
EOF
}

# Set KDE defaults via kwriteconfig5
configure_kde_defaults() {
    echo "Configuring KDE defaults..."
    
    # Global KDE settings
    kwriteconfig5 --file kdeglobals --group KDE \
        --key SingleClick false  # Double-click to open
    
    # Dolphin settings
    kwriteconfig5 --file dolphinrc --group General \
        --key ShowHiddenFiles false \
        --key OpenExternallyCalledFolderInNewTab false
    
    # Konsole settings
    kwriteconfig5 --file konsolerc --group "Desktop Entry" \
        --key DefaultProfile "Personal.profile"
    
    # KWin window management
    kwriteconfig5 --file kwinrc --group Windows \
        --key FocusPolicy "FocusFollowsMouse" \
        --key AutoRaise false
}

# Set keyboard shortcuts for window management
setup_kde_shortcuts() {
    echo "Setting up KDE keyboard shortcuts..."
    
    # Window tiling shortcuts (like your Sway setup)
    kwriteconfig5 --file kglobalshortcutsrc --group kwin \
        --key "Window Quick Tile Left" "Meta+Left,Meta+Left,Quick Tile Window to the Left" \
        --key "Window Quick Tile Right" "Meta+Right,Meta+Right,Quick Tile Window to the Right" \
        --key "Window Maximize" "Meta+Up,Meta+Up,Maximize Window" \
        --key "Window Close" "Meta+Shift+Q,,Close Window" \
        --key "Switch Window Left" "Meta+H,,Switch to Window to the Left" \
        --key "Switch Window Right" "Meta+L,,Switch to Window to the Right"
}

# Install KWin scripts for tiling
install_kwin_scripts() {
    echo "Installing KWin tiling scripts..."
    
    # Install Polonium or Bismuth for tiling
    if command -v kpackagetool5 &> /dev/null; then
        # Download and install Polonium (or Bismuth)
        wget -O /tmp/polonium.kwinscript \
            "https://github.com/zeroxoneafour/polonium/releases/latest/download/polonium.kwinscript"
        kpackagetool5 --type=KWin/Script --install /tmp/polonium.kwinscript
    fi
}

# Main execution
setup_dolphin_bookmarks
configure_kde_defaults
setup_kde_shortcuts
install_kwin_scripts

echo "✅ KDE setup complete! Log out and back in for all changes."
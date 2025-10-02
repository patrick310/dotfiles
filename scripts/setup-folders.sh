#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-folders.sh

create_home_structure() {
    echo "Creating home folder structure..."
    
    local dirs=(
        "$HOME/code/personal"
        "$HOME/code/work"
        "$HOME/code/forks"
        "$HOME/code/spikes"
        "$HOME/code/archive"
        "$HOME/Documents/notes"
        "$HOME/Documents/books"
        "$HOME/bin"
        "$HOME/.config"
        "$HOME/.local/bin"
        "$HOME/.local/share"
        "$HOME/.local/state"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        echo "  ✓ $dir"
    done
}

set_xdg_user_dirs() {
    # Configure XDG directories
    cat > ~/.config/user-dirs.dirs << 'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_PUBLICSHARE_DIR="$HOME/.local/share/Public"
XDG_TEMPLATES_DIR="$HOME/.local/share/Templates"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF
    
    # Prevent auto-creation of unwanted folders
    echo "enabled=false" > ~/.config/user-dirs.conf
}

create_home_structure
set_xdg_user_dirs
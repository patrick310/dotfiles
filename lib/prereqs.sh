# shellcheck shell=bash

# Prerequisite checks and filesystem preparation helpers.

ensure_prerequisites() {
    echo "==> Checking prerequisites..."

    local packages_needed=false
    command -v stow &> /dev/null || packages_needed=true
    command -v git &> /dev/null || packages_needed=true

    if [ "$packages_needed" = false ]; then
        echo "    Prerequisites already installed"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would install: stow git"
        return
    fi

    echo "    Installing stow and git..."
    case $OS in
        ubuntu|debian)
            sudo apt update && sudo apt install -y stow git
            ;;
        opensuse*)
            sudo zypper install -y stow git
            ;;
        fedora)
            sudo dnf install -y stow git
            ;;
        *)
            echo "    Warning: Unknown OS, please install stow and git manually"
            return 1
            ;;
    esac
}

ensure_user_directories() {
    echo "==> Creating config directories..."

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would create base directories and run setup-folders ($PROFILE)"
        return
    fi

    mkdir -p ~/.config/bash
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/share
    mkdir -p ~/.local/state
    mkdir -p ~/.cache

    if [ -f "$DOTFILES_DIR/scripts/setup-folders.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-folders.sh" "$PROFILE"
    fi
}

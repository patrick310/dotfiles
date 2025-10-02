#!/usr/bin/env bash
# ~/dotfiles/bootstrap.sh - Idempotent dotfiles setup

set -e  # Exit on error

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_STATE_FILE="$DOTFILES_DIR/.stow_state"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Warning: Could not detect OS"
    OS="unknown"
fi

# Install prerequisites if missing
install_prerequisites() {
    echo "==> Checking prerequisites..."

    local packages_needed=false
    command -v stow &> /dev/null || packages_needed=true
    command -v git &> /dev/null || packages_needed=true

    if [ "$packages_needed" = false ]; then
        echo "    Prerequisites already installed"
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

# Create necessary directories (idempotent)
create_directories() {
    echo "==> Creating config directories..."
    mkdir -p ~/.config/bash
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/share
    mkdir -p ~/.cache
}

# Backup existing configs (only if not already done)
backup_configs() {
    local backup_date=$(date +%Y%m%d)

    if [ -f ~/.bashrc ] && [ ! -L ~/.bashrc ] && [ ! -f ~/.bashrc.backup.$backup_date ]; then
        echo "==> Backing up existing .bashrc..."
        cp ~/.bashrc ~/.bashrc.backup.$backup_date
    fi
}

# Check if a package is already stowed
is_stowed() {
    local package=$1
    grep -q "^$package$" "$STOW_STATE_FILE" 2>/dev/null
}

# Mark a package as stowed
mark_stowed() {
    local package=$1
    echo "$package" >> "$STOW_STATE_FILE"
}

# Stow a package if not already stowed
stow_package() {
    local package=$1

    if [ ! -d "$DOTFILES_DIR/$package" ]; then
        echo "    Warning: Package '$package' directory not found, skipping"
        return
    fi

    if is_stowed "$package"; then
        echo "    $package: already stowed, restowing..."
        stow --restow "$package"
    else
        echo "    $package: stowing for first time..."
        stow "$package"
        mark_stowed "$package"
    fi
}

# Stow configurations
stow_dotfiles() {
    echo "==> Stowing configurations..."
    cd "$DOTFILES_DIR"

    # Stow each package
    stow_package "shell"
    stow_package "nvim"
    stow_package "kde"
}

# Ensure bashrc sources our config (idempotent)
configure_bashrc() {
    if grep -q ".config/bash/bashrc" ~/.bashrc 2>/dev/null; then
        echo "==> .bashrc already configured"
        return
    fi

    echo "==> Configuring .bashrc to source custom config..."
    cat >> ~/.bashrc << 'EOF'

# Source custom bash configuration
[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc
EOF
}

# Install distro-specific packages
install_packages() {
    if [ -f "$DOTFILES_DIR/install/$OS.sh" ] && [ -s "$DOTFILES_DIR/install/$OS.sh" ]; then
        echo "==> Running $OS-specific package installation..."
        bash "$DOTFILES_DIR/install/$OS.sh"
    fi
}

# Run setup scripts
run_setup_scripts() {
    echo "==> Running setup scripts..."

    # Folder structure
    if [ -f "$DOTFILES_DIR/scripts/setup-folders.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-folders.sh"
    fi

    # KDE setup (only if running KDE)
    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && [ -f "$DOTFILES_DIR/scripts/setup-kde.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-kde.sh"
    fi

    # Secrets setup (only if private-dots exists and script exists)
    if [ -d "$HOME/private-dots" ] && [ -f "$DOTFILES_DIR/scripts/setup-secrets.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-secrets.sh"
    fi
}

# Main execution
main() {
    echo "🔧 Bootstrapping dotfiles..."
    echo

    install_prerequisites
    create_directories
    backup_configs
    stow_dotfiles
    configure_bashrc
    install_packages
    run_setup_scripts

    echo
    echo "✅ Bootstrap complete!"
    echo "📝 Review changes: cd $DOTFILES_DIR && git status"
    echo "🔄 Reload shell: source ~/.bashrc"
}

main "$@"
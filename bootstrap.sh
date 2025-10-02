#!/usr/bin/env bash
# ~/dotfiles/bootstrap.sh

set -e  # Exit on error

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# Install stow and git if needed
echo "Installing prerequisites..."
case $OS in
    ubuntu|debian)
        sudo apt update
        sudo apt install -y stow git
        ;;
    opensuse*)
        sudo zypper install -y stow git
        ;;
    fedora)
        sudo dnf install -y stow git
        ;;
esac

# Create necessary directories
echo "Creating config directories..."
mkdir -p ~/.config/bash
mkdir -p ~/.local/bin
mkdir -p ~/.cache

# Backup existing configs
if [ -f ~/.bashrc ] && [ ! -L ~/.bashrc ]; then
    echo "Backing up existing .bashrc..."
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)
fi

# Stow configurations
echo "Stowing configurations..."
cd "$DOTFILES_DIR"

# Use adopt to handle existing files gracefully
stow --adopt shell
stow --adopt nvim
# Add other packages as needed

# Ensure bashrc sources our config
if ! grep -q ".config/bash/bashrc" ~/.bashrc 2>/dev/null; then
    echo "Adding source to .bashrc..."
    cat >> ~/.bashrc << 'EOF'

# Source custom bash configuration
[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc
EOF
fi

# Install distro-specific packages (optional)
if [ -f "$DOTFILES_DIR/install/$OS.sh" ]; then
    echo "Running $OS-specific setup..."
    bash "$DOTFILES_DIR/install/$OS.sh"
fi

echo "✅ Bootstrap complete!"
echo "📝 Review any adopted files with: cd $DOTFILES_DIR && git status"
echo "🔄 Reload shell with: source ~/.bashrc"

# Run setup scripts
echo "Setting up folder structure..."
./scripts/setup-folders.sh

# Stow configurations
stow shell
stow kde  # Only configs, not scripts


# Desktop environment specific setup
if [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
    ./scripts/setup-kde.sh
fi

# Secrets setup (if private repo exists)
if [ -d "$HOME/private-dots" ]; then
    ./scripts/setup-secrets.sh
fi
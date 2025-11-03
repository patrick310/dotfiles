#!/bin/bash
# Simple dotfiles installer using GNU Stow

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> Installing dotfiles"

# Check prerequisites
if ! command -v stow >/dev/null 2>&1; then
    echo "❌ GNU Stow is required but not installed."
    echo ""
    echo "Install it with:"
    echo "  openSUSE: sudo zypper in stow"
    echo "  Ubuntu:   sudo apt install stow"
    echo ""
    exit 1
fi

# Stow core configs
echo "📦 Installing shell and nvim configs..."
stow -d "$DOTFILES_DIR" -t "$HOME" shell
stow -d "$DOTFILES_DIR" -t "$HOME" nvim

# Configure .bashrc if needed
if ! grep -q ".config/bash/bashrc" ~/.bashrc 2>/dev/null; then
    echo "📝 Configuring .bashrc..."
    cat >> ~/.bashrc <<'RC'

# Source custom bash configuration
[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc
RC
fi

# Ask about KDE
if [ -d "$DOTFILES_DIR/kde" ]; then
    read -p "📦 Install KDE configs? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stow -d "$DOTFILES_DIR" -t "$HOME" kde
        echo "✓ KDE configs installed"

        # Offer to run KDE setup script
        if [ -f "$DOTFILES_DIR/scripts/setup-kde.sh" ]; then
            read -p "🔧 Run KDE setup script for tweaks? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                bash "$DOTFILES_DIR/scripts/setup-kde.sh"
            fi
        fi
    fi
fi

echo ""
echo "✅ Dotfiles installed!"
echo ""
echo "📦 Next: Install packages"
echo ""

# Detect OS and show relevant package install command
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        opensuse*|suse)
            echo "# openSUSE / SUSE:"
            echo "sudo zypper install \\"
            ;;
        ubuntu|debian)
            echo "# Ubuntu / Debian:"
            echo "sudo apt install \\"
            ;;
        fedora)
            echo "# Fedora:"
            echo "sudo dnf install \\"
            ;;
        *)
            echo "# Install these packages with your package manager:"
            echo ""
            ;;
    esac
fi

# Show common packages
cat "$DOTFILES_DIR/packages/common.txt" | grep -v '^#' | grep -v '^$' | tr '\n' ' '
echo ""

# Ask about profile
echo ""
read -p "📋 Profile? [d]esktop, [s]erver, or [n]one (default=none): " -n 1 -r profile
echo ""

case "$profile" in
    d|D)
        cat "$DOTFILES_DIR/packages/desktop.txt" | grep -v '^#' | grep -v '^$' | tr '\n' ' '
        echo ""
        ;;
    s|S)
        cat "$DOTFILES_DIR/packages/server.txt" | grep -v '^#' | grep -v '^$' | tr '\n' ' '
        echo ""
        ;;
esac

echo ""
echo "📝 After installing packages:"
echo "  - rustup: Run 'rustup install stable && rustup default stable'"
echo "  - ble.sh: Run ./scripts/install-blesh.sh (optional bash enhancement)"
echo ""
echo "📁 See templates/ for service configs:"
echo "  - templates/syncthing/  - File sync setup"
echo "  - templates/caddy/      - HTTPS reverse proxy"
echo "  - templates/headscale/  - Self-hosted VPN"
echo "  - templates/rclone/     - Cloud backup gateway"
echo ""

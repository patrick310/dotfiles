#!/usr/bin/env bash
# Fedora-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OS="${OS:-fedora}"
PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"

# shellcheck source=lib/packages.sh
source "$DOTFILES_DIR/lib/packages.sh"

collect_packages_for_profile "$PROFILE"
map_packages_for_os "$OS"

echo "Installing packages for Fedora (profile: $PROFILE)..."

if [ ${#MAPPED_PACKAGES[@]} -eq 0 ]; then
    echo "No packages requested, skipping"
    exit 0
fi

echo "Installing packages (missing packages will be noted)..."
sudo dnf install -y "${MAPPED_PACKAGES[@]}" || echo "Some packages may have failed to install"

# Install Bitwarden CLI via snap if available
if command -v snap &> /dev/null; then
    echo "Installing Bitwarden CLI via snap..."
    sudo snap install bw
else
    echo "Note: Snap not available, install Bitwarden CLI manually from:"
    echo "  https://bitwarden.com/help/cli/"
fi

# Install Node.js tools globally
echo "Installing global npm packages..."
packages_to_install=()

command -v pnpm &> /dev/null || packages_to_install+=(pnpm)
command -v yarn &> /dev/null || packages_to_install+=(yarn)

if [ ${#packages_to_install[@]} -gt 0 ]; then
    echo "  Installing: ${packages_to_install[*]}"
    sudo npm install -g "${packages_to_install[@]}"
else
    echo "  All global npm packages already installed"
fi

echo "✅ Fedora package installation complete!"

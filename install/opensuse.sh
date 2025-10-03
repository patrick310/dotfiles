#!/usr/bin/env bash
# openSUSE-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OS="${OS:-opensuse}"
PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"

# shellcheck source=lib/packages.sh
source "$DOTFILES_DIR/lib/packages.sh"

collect_packages_for_profile "$PROFILE"
map_packages_for_os "$OS"

echo "Installing packages for openSUSE (profile: $PROFILE)..."

if [ ${#MAPPED_PACKAGES[@]} -eq 0 ]; then
    echo "No packages requested, skipping"
    exit 0
fi

echo "Installing packages (missing packages will be skipped)..."
sudo zypper install -y --no-recommends "${MAPPED_PACKAGES[@]}" 2>&1 || echo "Note: Some packages may not be available"

# Install Snap (if not already installed)
if ! command -v snap &> /dev/null; then
    echo "Installing Snap support..."

    if ! zypper lr | grep -q "snappy"; then
        sudo zypper ar -f https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed/ snappy
        sudo zypper --gpg-auto-import-keys refresh
    fi

    sudo zypper dup --from snappy
    sudo zypper install -y snapd

    if command -v systemctl &> /dev/null; then
        sudo systemctl enable --now snapd
        sudo systemctl enable --now snapd.apparmor
    fi

    sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

    echo "✅ Snap installed (restarting snapd for socket setup...)"
    sudo systemctl restart snapd
    sleep 2
else
    echo "Snap already installed"
fi

# Install Bitwarden CLI via snap if available
if command -v snap &> /dev/null; then
    echo "Installing Bitwarden CLI via snap..."
    if ! sudo snap install bw 2>&1; then
        echo "⚠️  Snap installation had issues (snap may need initialization)"
        echo "   Fix with: sudo ln -sf /var/lib/snapd/snap /snap && sudo systemctl restart snapd"
        echo "   Then retry: sudo snap install bw"
    fi
else
    echo "Note: Snap not available, install Bitwarden CLI manually from:"
    echo "  https://bitwarden.com/help/cli/"
fi

# Install Node.js tools globally
if command -v npm &> /dev/null; then
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
else
    echo "⚠️  npm not found, skipping global package installation"
    echo "   Install with: sudo zypper install npm-default"
fi

echo "✅ openSUSE package installation complete!"

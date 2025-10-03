#!/usr/bin/env bash
# openSUSE-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"

echo "Installing packages for openSUSE..."

# Read package list, filter comments and empty lines
packages=$(grep -v '^#' "$COMMON_PACKAGES" | grep -v '^$' | tr '\n' ' ')

# openSUSE-specific package name mappings
opensuse_packages=$(echo "$packages" | \
    sed 's/fd-find/fd/g' | \
    sed 's/g++/gcc-c++/g' | \
    sed 's/dnsutils/bind-utils/g' | \
    sed 's/\<nodejs\>/nodejs-default/g' | \
    sed 's/\<npm\>/npm-default/g')

# Install packages (zypper will skip packages not found)
echo "Installing packages (missing packages will be skipped)..."
sudo zypper install -y --no-recommends $opensuse_packages 2>&1 || echo "Note: Some packages may not be available"

# Install Snap (if not already installed)
if ! command -v snap &> /dev/null; then
    echo "Installing Snap support..."

    # Add repo if not already present
    if ! zypper lr | grep -q "snappy"; then
        sudo zypper ar -f https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed/ snappy
        sudo zypper --gpg-auto-import-keys refresh
    fi

    # Install snapd (official method with dup from snappy repo)
    sudo zypper dup --from snappy
    sudo zypper install -y snapd

    # Enable snapd services
    if command -v systemctl &> /dev/null; then
        sudo systemctl enable --now snapd
        sudo systemctl enable --now snapd.apparmor
    fi

    # Create snapd socket symlink (required for openSUSE)
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

# Install SOPS from OBS repository
if ! command -v sops &> /dev/null; then
    echo "Installing SOPS from OBS..."

    # Detect openSUSE version
    if grep -q "Tumbleweed" /etc/os-release; then
        SOPS_REPO="https://download.opensuse.org/repositories/security:/Privacy/openSUSE_Tumbleweed/security:Privacy.repo"
    elif grep -q "15.6" /etc/os-release; then
        SOPS_REPO="https://download.opensuse.org/repositories/security:/Privacy/15.6/security:Privacy.repo"
    elif grep -q "15.5" /etc/os-release; then
        SOPS_REPO="https://download.opensuse.org/repositories/security:/Privacy/15.5/security:Privacy.repo"
    else
        # Default to Tumbleweed
        SOPS_REPO="https://download.opensuse.org/repositories/security:/Privacy/openSUSE_Tumbleweed/security:Privacy.repo"
    fi

    sudo zypper addrepo "$SOPS_REPO"
    sudo zypper --gpg-auto-import-keys refresh
    sudo zypper install -y sops
    echo "✅ SOPS installed"
fi

echo "✅ openSUSE package installation complete!"

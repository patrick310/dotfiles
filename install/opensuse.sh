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
    sed 's/dnsutils/bind-utils/g')

# Install packages
sudo zypper install -y $opensuse_packages

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
sudo npm install -g pnpm yarn

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

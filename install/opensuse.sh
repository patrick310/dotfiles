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

echo " openSUSE package installation complete!"

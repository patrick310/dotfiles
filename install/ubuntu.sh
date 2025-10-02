#!/usr/bin/env bash
# Ubuntu/Debian-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"

echo "Installing packages for Ubuntu/Debian..."

# Read package list, filter comments and empty lines
packages=$(grep -v '^#' "$COMMON_PACKAGES" | grep -v '^$' | tr '\n' ' ')

# Ubuntu-specific package name mappings
ubuntu_packages=$(echo "$packages" | \
    sed 's/fd-find/fd-find/g' | \
    sed 's/g++/g++/g' | \
    sed 's/dnsutils/dnsutils/g')

# Update package list
sudo apt update

# Install packages
sudo apt install -y $ubuntu_packages

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

echo "✅ Ubuntu/Debian package installation complete!"

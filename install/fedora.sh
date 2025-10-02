#!/usr/bin/env bash
# Fedora-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"

echo "Installing packages for Fedora..."

# Read package list, filter comments and empty lines
packages=$(grep -v '^#' "$COMMON_PACKAGES" | grep -v '^$' | tr '\n' ' ')

# Fedora-specific package name mappings
fedora_packages=$(echo "$packages" | \
    sed 's/fd-find/fd-find/g' | \
    sed 's/python3-pip/python3-pip/g' | \
    sed 's/dnsutils/bind-utils/g')

# Install packages
sudo dnf install -y $fedora_packages

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

echo " Fedora package installation complete!"

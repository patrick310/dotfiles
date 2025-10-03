#!/usr/bin/env bash
# Ubuntu/Debian-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"
PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"
PROFILE_PACKAGES="$SCRIPT_DIR/profiles/${PROFILE}.txt"

echo "Installing packages for Ubuntu/Debian (profile: $PROFILE)..."

read_packages() {
    local file=$1
    [[ -f $file ]] || return 0

    while IFS= read -r line; do
        [[ -z $line || $line =~ ^# ]] && continue
        packages+=("$line")
    done < "$file"
}

dedupe_packages() {
    declare -A seen=()
    local deduped=()
    for pkg in "${packages[@]}"; do
        if [[ -n $pkg && -z ${seen[$pkg]} ]]; then
            deduped+=("$pkg")
            seen[$pkg]=1
        fi
    done
    packages=("${deduped[@]}")
}

packages=()
read_packages "$COMMON_PACKAGES"
if [ -f "$PROFILE_PACKAGES" ]; then
    read_packages "$PROFILE_PACKAGES"
else
    echo "⚠️  Profile package list not found: install/profiles/${PROFILE}.txt"
fi
dedupe_packages

if [ ${#packages[@]} -eq 0 ]; then
    echo "No packages requested, skipping"
    exit 0
fi

# Ensure software-properties-common is installed (needed for add-apt-repository)
if ! dpkg -l | grep -q software-properties-common; then
    echo "Installing software-properties-common..."
    sudo apt update
    sudo apt install -y software-properties-common
fi

# Add Neovim unstable PPA for latest version
if ! grep -q "neovim-ppa/unstable" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    echo "Adding Neovim unstable PPA..."
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
fi

# Update package list
sudo apt update

echo "Installing packages (missing packages will be noted)..."
sudo apt install -y "${packages[@]}" || echo "Some packages may have failed to install"

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

echo "✅ Ubuntu/Debian package installation complete!"

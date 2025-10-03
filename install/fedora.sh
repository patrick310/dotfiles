#!/usr/bin/env bash
# Fedora-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"
PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"
PROFILE_PACKAGES="$SCRIPT_DIR/profiles/${PROFILE}.txt"

echo "Installing packages for Fedora (profile: $PROFILE)..."

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

map_package_name() {
    local pkg=$1
    case $pkg in
        fd-find) echo "fd-find" ;;
        dnsutils) echo "bind-utils" ;;
        *) echo "$pkg" ;;
    esac
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

mapped_packages=()
for pkg in "${packages[@]}"; do
    mapped_packages+=("$(map_package_name "$pkg")")
done

echo "Installing packages (missing packages will be noted)..."
sudo dnf install -y "${mapped_packages[@]}" || echo "Some packages may have failed to install"

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

#!/usr/bin/env bash
# openSUSE-specific package installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_PACKAGES="$SCRIPT_DIR/common.txt"
PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"
PROFILE_PACKAGES="$SCRIPT_DIR/profiles/${PROFILE}.txt"

echo "Installing packages for openSUSE (profile: $PROFILE)..."

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
        fd-find) echo "fd" ;;
        g++) echo "gcc-c++" ;;
        dnsutils) echo "bind-utils" ;;
        nodejs) echo "nodejs-default" ;;
        npm) echo "npm-default" ;;
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

echo "Installing packages (missing packages will be skipped)..."
sudo zypper install -y --no-recommends "${mapped_packages[@]}" 2>&1 || echo "Note: Some packages may not be available"

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

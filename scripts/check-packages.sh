#!/usr/bin/env bash
# ~/dotfiles/scripts/check-packages.sh - Report missing packages for a profile

set -euo pipefail

PROFILE="${1:-${BOOTSTRAP_PROFILE:-desktop}}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

# shellcheck source=lib/os.sh
source "$DOTFILES_DIR/lib/os.sh"
# shellcheck source=lib/packages.sh
source "$DOTFILES_DIR/lib/packages.sh"

detect_os
collect_packages_for_profile "$PROFILE"
map_packages_for_os "$OS"

echo "==> Package availability check"
echo "    OS: $OS"
echo "    Profile: $PROFILE"

if [ ${#MAPPED_PACKAGES[@]} -eq 0 ]; then
    echo "    (no packages defined)"
    exit 0
fi

package_manager=""
if command -v dpkg &> /dev/null; then
    package_manager="dpkg"
elif command -v rpm &> /dev/null; then
    package_manager="rpm"
elif command -v pacman &> /dev/null; then
    package_manager="pacman"
fi

if [ -z "$package_manager" ]; then
    echo "    ℹ️  Package manager not detected; skipping installation check"
    exit 0
fi

missing=()
for pkg in "${MAPPED_PACKAGES[@]}"; do
    case $package_manager in
        dpkg)
            dpkg -s "$pkg" &> /dev/null || missing+=("$pkg")
            ;;
        rpm)
            rpm -q "$pkg" &> /dev/null || missing+=("$pkg")
            ;;
        pacman)
            pacman -Qi "$pkg" &> /dev/null || missing+=("$pkg")
            ;;
    esac
done

if [ ${#missing[@]} -eq 0 ]; then
    echo "    ✓ All tracked packages appear installed"
else
    echo "    ⚠️  Missing packages:"
    for pkg in "${missing[@]}"; do
        echo "      - $pkg"
    done
    echo "    (Install with: ./install/$OS.sh $PROFILE)"
    exit 1
fi

#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-sync.sh - Unified sync setup facade
#
# Delegates to appropriate backend based on profile

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-desktop}"

# Source libraries
# shellcheck source=lib/sync.sh
source "$DOTFILES_DIR/lib/sync.sh"
# shellcheck source=lib/service-user.sh
source "$DOTFILES_DIR/lib/service-user.sh"
# shellcheck source=lib/systemd.sh
source "$DOTFILES_DIR/lib/systemd.sh"

main() {
    case "$PROFILE" in
        gateway)
            echo "==> Setting up Sync Gateway"
            bash "$DOTFILES_DIR/scripts/setup-sync-gateway.sh"
            ;;
        minimal|desktop|server)
            echo "==> Setting up Syncthing (Personal Device)"
            bash "$DOTFILES_DIR/scripts/setup-syncthing.sh" "$PROFILE"
            ;;
        *)
            echo "❌ Unknown profile: $PROFILE"
            echo "   Valid profiles: minimal, desktop, server, gateway"
            exit 1
            ;;
    esac
}

main "$@"

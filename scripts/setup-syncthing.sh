#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-syncthing.sh - Setup Syncthing for personal devices
#
# Usage: ./setup-syncthing.sh [profile]
#   profile: minimal|desktop|server (not gateway)

set -eo pipefail

PROFILE="${1:-desktop}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
# shellcheck source=lib/sync.sh
source "$DOTFILES_DIR/lib/sync.sh"

# Check if syncthing is installed
check_syncthing() {
    if ! command -v syncthing &> /dev/null; then
        echo "❌ Syncthing not found"
        echo "   Install it with: sudo apt install syncthing"
        echo "   Or it will be installed during package installation"
        return 1
    fi
    return 0
}

# Setup systemd service
setup_systemd_service() {
    echo "    Setting up Syncthing systemd service..."

    # Use library function to setup systemd service
    setup_syncthing_systemd
}

# Get device ID
show_device_id() {
    echo ""
    echo "    📱 Your Syncthing Device ID:"

    # Use library function to get device ID
    local device_id
    device_id=$(get_syncthing_device_id)

    if [ -n "$device_id" ]; then
        echo ""
        echo "      $device_id"
        echo ""
    else
        echo "      (Device ID will be available after first start)"
        echo "      Run: syncthing --device-id"
        echo ""
    fi
}

# Show folders to sync
show_folders_to_sync() {
    echo "    📁 Folders to share with gateway server:"
    echo ""

    # Source the folder config from setup-folders.sh
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Get syncthing folders for this profile
    # shellcheck source=scripts/setup-folders.sh
    source "$script_dir/setup-folders.sh" "$PROFILE" &> /dev/null

    local syncthing_folders
    mapfile -t syncthing_folders < <(get_folders_by_sync_type "syncthing")

    for folder in "${syncthing_folders[@]}"; do
        echo "      - ${folder/#$HOME/~}"
    done

    echo ""
}

# Show instructions
show_instructions() {
    echo "    📝 Next steps:"
    echo ""
    echo "      1. Open local Syncthing Web GUI:"
    echo "         http://localhost:8384"
    echo ""
    echo "      2. Click 'Add Remote Device' in bottom-right"
    echo ""
    echo "      3. Get gateway device ID from:"

    local config_file="$HOME/private-dots/config/sync-devices.yaml"
    if [ -f "$config_file" ]; then
        local gateway_id
        if command -v yq &> /dev/null; then
            gateway_id=$(yq '.gateway.device_id' "$config_file" 2>/dev/null)
        else
            gateway_id=$(grep 'device_id:' "$config_file" | head -1 | sed 's/.*device_id: *"\?\([^"]*\)"\?.*/\1/')
        fi

        if [ -n "$gateway_id" ] && [ "$gateway_id" != "PLACEHOLDER-WILL-BE-FILLED-ON-FIRST-SETUP" ]; then
            echo "         $gateway_id"
            echo "         (from ~/private-dots/config/sync-devices.yaml)"
        else
            echo "         ~/private-dots/config/sync-devices.yaml (after gateway setup)"
            echo "         or ask gateway admin"
        fi
    else
        echo "         Ask gateway server admin"
    fi
    echo ""
    echo "      4. Gateway admin will accept your device connection at:"
    echo "         http://gateway-server:8384"
    echo ""
    echo "      5. Share folders listed above with gateway server"
    echo ""
    echo "      6. Check sync status:"
    echo "         ~/dotfiles/scripts/sync-status.sh"
    echo ""
}

# Main execution
main() {
    echo "==> Setting up Syncthing for profile: $PROFILE"

    if ! check_syncthing; then
        echo "    Skipping Syncthing setup (not installed yet)"
        echo "    Run this script again after package installation"
        return 0
    fi

    setup_systemd_service
    show_device_id
    show_folders_to_sync
    show_instructions

    echo "✅ Syncthing setup complete!"
}

main

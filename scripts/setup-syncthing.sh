#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-syncthing.sh - Setup Syncthing for personal devices
#
# Usage: ./setup-syncthing.sh [profile]
#   profile: minimal|desktop|server (not gateway)

PROFILE="${1:-desktop}"

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

    # Enable user service
    systemctl --user enable syncthing.service &> /dev/null || true
    systemctl --user start syncthing.service &> /dev/null || true

    # Wait for syncthing to start
    sleep 2

    if systemctl --user is-active syncthing.service &> /dev/null; then
        echo "      ✓ Syncthing service enabled and started"
    else
        echo "      ⚠️  Syncthing service may not be running yet"
        echo "         Start manually: systemctl --user start syncthing"
    fi
}

# Get device ID
show_device_id() {
    echo ""
    echo "    📱 Your Syncthing Device ID:"

    # Try to get device ID
    local device_id
    if [ -f ~/.local/state/syncthing/cert.pem ]; then
        device_id=$(syncthing --device-id 2>/dev/null)
    elif [ -f ~/.config/syncthing/cert.pem ]; then
        device_id=$(syncthing --device-id 2>/dev/null)
    fi

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
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Get syncthing folders for this profile
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
    echo "      1. Open Syncthing Web GUI:"
    echo "         http://localhost:8384"
    echo ""
    echo "      2. Add your gateway server:"
    echo "         - Click 'Add Remote Device'"
    echo "         - Enter gateway server's Device ID"
    echo "         - Select folders to share"
    echo ""
    echo "      3. On gateway server, accept device connection"
    echo ""
    echo "      4. Check sync status:"
    echo "         ./scripts/sync-status.sh"
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

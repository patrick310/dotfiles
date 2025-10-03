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

# Auto-add gateway server from config
auto_add_gateway() {
    echo "    Auto-configuring gateway server..."

    local config_file="$HOME/private-dots/config/sync-devices.yaml"

    # Check if config exists
    if [ ! -f "$config_file" ]; then
        echo "      ⚠️  Gateway not configured yet"
        echo "         Run setup on gateway server first, then:"
        echo "         cd ~/private-dots && git pull"
        return 1
    fi

    # Get gateway device ID from config
    local gateway_id
    if command -v yq &> /dev/null; then
        gateway_id=$(yq '.gateway.device_id' "$config_file" 2>/dev/null)
    else
        # Fallback: parse YAML manually
        gateway_id=$(grep 'device_id:' "$config_file" | head -1 | sed 's/.*device_id: *"\?\([^"]*\)"\?.*/\1/')
    fi

    if [ -z "$gateway_id" ] || [ "$gateway_id" = "PLACEHOLDER-WILL-BE-FILLED-ON-FIRST-SETUP" ]; then
        echo "      ⚠️  Gateway device ID not found in config"
        echo "         Setup gateway server or update config manually"
        return 1
    fi

    # Find Syncthing config file
    local config_xml
    if [ -f ~/.local/state/syncthing/config.xml ]; then
        config_xml=~/.local/state/syncthing/config.xml
    elif [ -f ~/.config/syncthing/config.xml ]; then
        config_xml=~/.config/syncthing/config.xml
    else
        echo "      ⚠️  Syncthing config not found (not started yet?)"
        echo "         Wait for Syncthing to start, then run again"
        return 1
    fi

    # Get API key from config
    local api_key
    api_key=$(grep '<apikey>' "$config_xml" | sed 's/.*<apikey>\(.*\)<\/apikey>/\1/')

    if [ -z "$api_key" ]; then
        echo "      ⚠️  Could not get Syncthing API key"
        return 1
    fi

    # Check if gateway already configured
    local existing
    existing=$(curl -s -H "X-API-Key: $api_key" \
        http://localhost:8384/rest/config/devices 2>/dev/null | \
        grep -c "$gateway_id" || true)

    if [ "$existing" -gt 0 ]; then
        echo "      ✓ Gateway already configured in Syncthing"
        return 0
    fi

    # Add gateway device via REST API
    echo "      Adding gateway server to Syncthing..."

    # Get current config
    local current_config
    current_config=$(curl -s -H "X-API-Key: $api_key" \
        http://localhost:8384/rest/config 2>/dev/null)

    # Add device to config
    local new_device="{\"deviceID\": \"$gateway_id\", \"name\": \"Gateway Server\", \"addresses\": [\"dynamic\"], \"compression\": \"metadata\", \"introducer\": false, \"skipIntroductionRemovals\": false, \"introducedBy\": \"\", \"paused\": false, \"allowedNetworks\": [], \"autoAcceptFolders\": false, \"maxSendKbps\": 0, \"maxRecvKbps\": 0}"

    # Update config with new device
    echo "$current_config" | jq ".devices += [$new_device]" | \
        curl -s -X PUT -H "X-API-Key: $api_key" \
        -H "Content-Type: application/json" \
        http://localhost:8384/rest/config \
        -d @- > /dev/null

    echo ""
    echo "      ✓ Gateway device added to Syncthing"
    echo "      ⏳ Pending approval on gateway server"
    echo "         Gateway admin must approve connection at:"
    echo "         http://gateway-server:8384"
    echo ""
}

# Show instructions
show_instructions() {
    echo "    📝 Next steps:"
    echo ""
    echo "      1. On gateway server, accept this device's connection:"
    echo "         - Open http://gateway-server:8384"
    echo "         - Click notification to accept device"
    echo "         - Select folders to share"
    echo ""
    echo "      2. Open local Syncthing Web GUI to monitor:"
    echo "         http://localhost:8384"
    echo ""
    echo "      3. Check sync status:"
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
    auto_add_gateway
    show_folders_to_sync
    show_instructions

    echo "✅ Syncthing setup complete!"
}

main

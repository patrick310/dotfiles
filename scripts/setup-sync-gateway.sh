#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-sync-gateway.sh - Setup sync gateway server
#
# This server acts as a bridge between Syncthing (devices) and Google Drive (cloud)

set -eo pipefail

PROFILE="gateway"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
# shellcheck source=lib/sync.sh
source "$DOTFILES_DIR/lib/sync.sh"
# shellcheck source=lib/service-user.sh
source "$DOTFILES_DIR/lib/service-user.sh"
# shellcheck source=lib/systemd.sh
source "$DOTFILES_DIR/lib/systemd.sh"
# shellcheck source=lib/backup.sh
source "$DOTFILES_DIR/lib/backup.sh"

# Check prerequisites
check_prerequisites() {
    local missing=()

    if ! command -v syncthing &> /dev/null; then
        missing+=("syncthing")
    fi

    if ! command -v rclone &> /dev/null; then
        missing+=("rclone")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Missing packages: ${missing[*]}"
        echo "   Install them or run package installation first"
        return 1
    fi

    return 0
}

# Setup Syncthing
setup_syncthing() {
    echo "    Setting up Syncthing..."

    # Use library function to setup systemd service
    setup_syncthing_systemd

    # Show device ID
    echo ""
    echo "    📱 Gateway Server Device ID:"

    local device_id
    device_id=$(get_syncthing_device_id)

    if [ -n "$device_id" ]; then
        echo ""
        echo "      $device_id"
        echo ""
        echo "      📝 Share this ID with your personal devices"
    else
        echo "      (Run: syncthing --device-id)"
    fi
    echo ""
}

# Save gateway device ID to private config
save_gateway_device_id() {
    echo "    Saving gateway device ID to config..."

    # Use library function with retry logic
    local device_id
    if ! device_id=$(get_syncthing_device_id_with_retry 5); then
        echo "      ⚠️  Could not get device ID after 5 attempts"
        echo "         Run script again or check manually: syncthing --device-id"
        return 1
    fi

    local hostname
    hostname=$(hostname)
    local config_file="$HOME/private-dots/config/sync-devices.yaml"

    # Create config directory if needed
    mkdir -p "$(dirname "$config_file")"

    # Update or create config file
    if ! command -v yq &> /dev/null; then
        echo "      ⚠️  yq not installed, creating config manually"
        cat > "$config_file" << EOF
# Syncthing device registry
gateway:
  device_id: "$device_id"
  name: "Gateway Server"
  hostname: "$hostname"
devices: []
EOF
    else
        # Use yq if available
        if [ ! -f "$config_file" ]; then
            # Create template first
            cat > "$config_file" << EOF
gateway:
  device_id: ""
  name: "Gateway Server"
  hostname: ""
devices: []
EOF
        fi
        yq -i ".gateway.device_id = \"$device_id\"" "$config_file"
        yq -i ".gateway.hostname = \"$hostname\"" "$config_file"
    fi

    echo "      ✓ Device ID saved to private-dots/config/sync-devices.yaml"
    echo "      💡 Commit this to your private-dots repo:"
    echo "         cd ~/private-dots && git add config/ && git commit -m 'Add gateway device ID'"
}

# Setup Rclone service user
setup_rclone_user() {
    echo "    Setting up rclone-sync service user..."

    create_service_user "rclone-sync" "/var/lib/rclone-sync"
    setup_service_directories "rclone-sync" "/var/lib/rclone-sync" "/var/log/rclone-sync"

    echo "      ✓ Service user created"
}

# Setup Rclone
setup_rclone() {
    echo "    Setting up Rclone..."

    # Check if gdrive remote already exists
    if rclone listremotes 2>/dev/null | grep -q "^gdrive:"; then
        echo "      ✓ Rclone already configured with 'gdrive' remote"
        return 0
    fi

    echo ""
    echo "    ⚙️  Rclone needs to be configured for Google Drive"
    echo ""
    echo "    Steps:"
    echo "      1. Choose 'n' for new remote"
    echo "      2. Name it: gdrive"
    echo "      3. Choose 'drive' for Google Drive"
    echo "      4. Leave client_id and client_secret blank"
    echo "      5. Choose 'n' for advanced config"
    echo "      6. Choose 'y' for auto config (OAuth browser flow)"
    echo "      7. Choose 'n' for team drive"
    echo "      8. Confirm with 'y'"
    echo ""
    read -r -p "    Press Enter to start rclone config..."

    rclone config

    # Verify setup
    if rclone listremotes 2>/dev/null | grep -q "^gdrive:"; then
        echo ""
        echo "      ✓ Rclone configured successfully"
    else
        echo ""
        echo "      ⚠️  Rclone may not be configured correctly"
        echo "         Run 'rclone config' manually to fix"
    fi
}

# Create sync script
create_sync_script() {
    echo "    Creating cloud sync script..."

    # Get syncthing folders for gateway profile
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local folders=()

    if source "$script_dir/setup-folders.sh" "gateway" > /dev/null 2>&1; then
        mapfile -t folders < <(get_folders_by_sync_type "syncthing")
    fi

    mkdir -p ~/bin

    cat > ~/bin/sync-to-cloud.sh << 'SCRIPT_START'
#!/bin/bash
# Generated sync script - Syncs folders to Google Drive
# Excludes Syncthing metadata

LOG_FILE="$HOME/.local/state/sync-to-cloud.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Sync started: $(date) ===" >> "$LOG_FILE"

sync_folder() {
    local folder=$1
    local remote=$2

    if [ -d "$folder" ]; then
        echo "Syncing $folder..." >> "$LOG_FILE"
        rclone sync "$folder" "$remote" \
            --exclude ".stversions/**" \
            --exclude ".stfolder/**" \
            --exclude ".stignore" \
            --log-file="$LOG_FILE" \
            --log-level INFO
    fi
}

SCRIPT_START

    # Add sync commands for each folder
    for folder in "${folders[@]}"; do
        local folder_name="${folder/#$HOME\//}"
        echo "sync_folder \"$folder\" \"gdrive:$folder_name\"" >> ~/bin/sync-to-cloud.sh
    done

    cat >> ~/bin/sync-to-cloud.sh << 'SCRIPT_END'

echo "=== Sync completed: $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
SCRIPT_END

    chmod +x ~/bin/sync-to-cloud.sh
    echo "      ✓ Created ~/bin/sync-to-cloud.sh (syncing ${#folders[@]} folders)"
}

# Setup cron job
setup_cron() {
    echo "    Setting up cron job for automatic sync..."

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "sync-to-cloud.sh"; then
        echo "      ✓ Cron job already exists"
        return 0
    fi

    # Add cron job (every 15 minutes)
    (crontab -l 2>/dev/null; echo "*/15 * * * * $HOME/bin/sync-to-cloud.sh") | crontab -

    echo "      ✓ Added cron job (runs every 15 minutes)"
    echo "         View log: ~/.local/state/sync-to-cloud.log"
}

# Show folders
show_gateway_folders() {
    echo ""
    echo "    📁 Gateway server will sync these folders:"
    echo ""

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=scripts/setup-folders.sh
    if ! source "$script_dir/setup-folders.sh" "$PROFILE" > /dev/null; then
        echo "      ⚠️  Could not load folder configuration"
        return 1
    fi

    local syncthing_folders
    mapfile -t syncthing_folders < <(get_folders_by_sync_type "syncthing")

    for folder in "${syncthing_folders[@]}"; do
        echo "      - ${folder/#$HOME/~} → Google Drive"
    done

    echo ""
}

# Show instructions
show_instructions() {
    echo "    📝 Next steps:"
    echo ""
    echo "      1. Add personal devices in Syncthing Web GUI:"
    echo "         http://localhost:8384"
    echo ""
    echo "      2. Accept device connections from your laptops/desktops"
    echo ""
    echo "      3. Share folders with connected devices"
    echo ""
    echo "      4. Test manual sync to cloud:"
    echo "         ~/bin/sync-to-cloud.sh"
    echo ""
    echo "      5. Monitor sync logs:"
    echo "         tail -f ~/.local/state/sync-to-cloud.log"
    echo ""
    echo "      6. Check overall status:"
    echo "         ./scripts/sync-status.sh"
    echo ""
}

# Main execution
main() {
    echo "==> Setting up Sync Gateway Server"

    if ! check_prerequisites; then
        echo "    Skipping gateway setup (missing prerequisites)"
        return 1
    fi

    setup_syncthing
    save_gateway_device_id
    setup_rclone_user
    setup_rclone
    create_sync_script
    setup_cron
    show_gateway_folders
    show_instructions

    echo "✅ Sync gateway setup complete!"
    echo ""
    echo "🔄 Your gateway server will:"
    echo "   - Accept Syncthing connections from your devices"
    echo "   - Backup to Google Drive every 15 minutes"
}

main

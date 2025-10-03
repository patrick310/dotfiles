#!/usr/bin/env bash
# ~/dotfiles/scripts/sync-status.sh - Show sync status for all backends

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Syncthing status
check_syncthing() {
    echo "==> Syncthing Status"
    echo ""

    if ! command -v syncthing &> /dev/null; then
        echo "  ❌ Syncthing not installed"
        echo ""
        return 1
    fi

    # Check if service is running
    if systemctl --user is-active syncthing.service &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Service: Running"

        # Show device ID
        local device_id
        if [ -f ~/.local/state/syncthing/cert.pem ]; then
            device_id=$(syncthing --device-id 2>/dev/null)
        elif [ -f ~/.config/syncthing/cert.pem ]; then
            device_id=$(syncthing --device-id 2>/dev/null)
        fi

        if [ -n "$device_id" ]; then
            echo "  📱 Device ID: $device_id"
        fi

        echo "  🌐 Web GUI: http://localhost:8384"
        echo ""

        # Try to get folder info via API (basic check)
        if command -v curl &> /dev/null; then
            local api_key
            if [ -f ~/.local/state/syncthing/config.xml ]; then
                api_key=$(grep '<apikey>' ~/.local/state/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>/\1/')
            elif [ -f ~/.config/syncthing/config.xml ]; then
                api_key=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>/\1/')
            fi

            if [ -n "$api_key" ]; then
                local folders_json
                if folders_json=$(curl -s -H "X-API-Key: $api_key" http://localhost:8384/rest/config/folders 2>/dev/null); then
                    if [ -n "$folders_json" ]; then
                        local folder_count
                        folder_count=$(echo "$folders_json" | grep -o '"id"' | wc -l)
                        echo "  📁 Shared folders: $folder_count"
                    fi
                fi
            fi
        fi
    else
        echo -e "  ${RED}❌${NC} Service: Not running"
        echo "     Start with: systemctl --user start syncthing"
    fi

    echo ""
}

# Check Rclone status (gateway only)
check_rclone() {
    echo "==> Rclone Status"
    echo ""

    if ! command -v rclone &> /dev/null; then
        echo "  ℹ️  Rclone not installed (not a gateway server)"
        echo ""
        return 0
    fi

    # Check if gdrive remote exists
    if rclone listremotes 2>/dev/null | grep -q "^gdrive:"; then
        echo -e "  ${GREEN}✓${NC} Remote 'gdrive' configured"

        # Check last sync time
        local log_file="$HOME/.local/state/sync-to-cloud.log"
        if [ -f "$log_file" ]; then
            local last_sync
            last_sync=$(grep "Sync completed:" "$log_file" | tail -1 | sed 's/.*: //')

            if [ -n "$last_sync" ]; then
                echo "  🕒 Last sync: $last_sync"
            else
                echo -e "  ${YELLOW}⚠️${NC}  No sync completed yet"
            fi

            # Show recent errors
            local error_count
            error_count=$(grep -c "ERROR" "$log_file" 2>/dev/null || echo "0")

            if [ "$error_count" -gt 0 ]; then
                echo -e "  ${RED}⚠️${NC}  Errors in log: $error_count"
                echo "     View with: tail ~/.local/state/sync-to-cloud.log"
            fi
        else
            echo -e "  ${YELLOW}⚠️${NC}  No sync log found (not run yet)"
        fi

        # Check cron job
        if crontab -l 2>/dev/null | grep -q "sync-to-cloud.sh"; then
            echo -e "  ${GREEN}✓${NC} Cron job: Configured (every 15 min)"
        else
            echo -e "  ${RED}❌${NC} Cron job: Not configured"
        fi
    else
        echo -e "  ${RED}❌${NC} Remote 'gdrive' not configured"
        echo "     Configure with: rclone config"
    fi

    echo ""
}

# Show disk usage for sync folders
check_disk_usage() {
    echo "==> Disk Usage (Synced Folders)"
    echo ""

    local folders=(
        "$HOME/Documents"
        "$HOME/Photos"
        "$HOME/playground"
        "$HOME/code"
    )

    for folder in "${folders[@]}"; do
        if [ -d "$folder" ]; then
            local size
            size=$(du -sh "$folder" 2>/dev/null | cut -f1)
            echo "  📁 ${folder/#$HOME/~}: $size"
        fi
    done

    echo ""
}

# Main execution
main() {
    echo "📊 Sync Status Report"
    echo ""

    check_syncthing
    check_rclone
    check_disk_usage

    echo "💡 Tip: Run setup scripts to configure sync"
    echo "   - Personal device: ./scripts/setup-syncthing.sh"
    echo "   - Gateway server:  ./scripts/setup-sync-gateway.sh"
}

main

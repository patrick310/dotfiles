#!/bin/bash
# shellcheck shell=bash
# Syncthing utilities shared between gateway and personal device setup

# Check if syncthing is installed
# Usage: check_syncthing_installed
check_syncthing_installed() {
    command -v syncthing &>/dev/null
}

# Get Syncthing device ID with retry logic
# Usage: device_id=$(get_syncthing_device_id)
get_syncthing_device_id() {
    local retries=0
    local max_retries=5
    local device_id=""

    while [ -z "$device_id" ] && [ $retries -lt $max_retries ]; do
        if [ -f ~/.local/state/syncthing/cert.pem ]; then
            device_id=$(syncthing --device-id 2>/dev/null)
        elif [ -f ~/.config/syncthing/cert.pem ]; then
            device_id=$(syncthing --device-id 2>/dev/null)
        fi

        if [ -z "$device_id" ]; then
            ((retries++))
            if [ $retries -lt $max_retries ]; then
                sleep 2
            fi
        fi
    done

    echo "$device_id"
}

# Get Syncthing API key from config
# Usage: api_key=$(get_syncthing_api_key)
get_syncthing_api_key() {
    local config_xml=""

    if [ -f ~/.local/state/syncthing/config.xml ]; then
        config_xml=~/.local/state/syncthing/config.xml
    elif [ -f ~/.config/syncthing/config.xml ]; then
        config_xml=~/.config/syncthing/config.xml
    fi

    if [ -n "$config_xml" ]; then
        grep '<apikey>' "$config_xml" | sed 's/.*<apikey>\(.*\)<\/apikey>/\1/'
    fi
}

# Setup and start Syncthing as a user service
# Usage: setup_syncthing_systemd
setup_syncthing_systemd() {
    echo "  Setting up Syncthing systemd service..."
    systemctl --user enable syncthing.service &>/dev/null || true
    systemctl --user start syncthing.service &>/dev/null || true

    # Wait a moment for service to start
    sleep 2

    if systemctl --user is-active syncthing.service &>/dev/null; then
        echo "  ✓ Syncthing service enabled and started"
        return 0
    else
        echo "  ⚠️  Syncthing service may not be running yet"
        return 1
    fi
}

# Wait for Syncthing to be fully ready (config.xml exists, API responding)
# Usage: wait_for_syncthing_ready [max_wait_seconds]
wait_for_syncthing_ready() {
    local max_wait=${1:-30}
    local count=0
    local config_exists=false
    local api_ready=false

    echo "  Waiting for Syncthing to be ready..."

    while [ $count -lt $max_wait ]; do
        # Check if config exists
        if [ -f ~/.local/state/syncthing/config.xml ] || [ -f ~/.config/syncthing/config.xml ]; then
            config_exists=true

            # Check if API is responding
            local api_key
            api_key=$(get_syncthing_api_key)
            if [ -n "$api_key" ]; then
                if curl -s -H "X-API-Key: $api_key" http://localhost:8384/rest/system/status &>/dev/null; then
                    api_ready=true
                    break
                fi
            fi
        fi

        sleep 1
        ((count++))
    done

    if [ "$api_ready" = true ]; then
        echo "  ✓ Syncthing is ready"
        return 0
    else
        echo "  ⚠️  Syncthing may not be fully ready"
        return 1
    fi
}

# Get device ID from config file (for gateway setup)
# Usage: device_id=$(get_syncthing_device_id_with_retry max_retries)
get_syncthing_device_id_with_retry() {
    local max_retries=${1:-5}
    local device_id=""
    local retries=0

    while [ -z "$device_id" ] && [ $retries -lt $max_retries ]; do
        device_id=$(get_syncthing_device_id)

        if [ -z "$device_id" ]; then
            ((retries++))
            echo "  ⏳ Waiting for Syncthing to start... ($retries/$max_retries)"
            sleep 2
        fi
    done

    if [ -n "$device_id" ]; then
        echo "$device_id"
        return 0
    else
        return 1
    fi
}

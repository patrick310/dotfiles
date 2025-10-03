#!/bin/bash
# shellcheck shell=bash
# Systemd service management utilities

# Enable and start a user service
# Usage: enable_user_service service_name
enable_user_service() {
    local service=$1

    echo "  Enabling user service: $service"
    systemctl --user daemon-reload
    systemctl --user enable "$service"
    systemctl --user start "$service"
}

# Create and enable a system service
# Usage: create_system_service service_name service_file_path
create_system_service() {
    local service_name=$1
    local service_file=$2

    echo "  Installing system service: $service_name"
    sudo cp "$service_file" "/etc/systemd/system/$service_name"
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"
}

# Wait for a user service to become active
# Usage: wait_for_user_service service_name [max_wait_seconds]
wait_for_user_service() {
    local service=$1
    local max_wait=${2:-30}
    local count=0

    echo "  Waiting for $service to start..."
    while ! systemctl --user is-active "$service" &>/dev/null; do
        sleep 1
        ((count++))
        if [ $count -ge $max_wait ]; then
            echo "  ⚠️  Service $service did not start within ${max_wait}s"
            return 1
        fi
    done
    echo "  ✓ Service $service is active"
    return 0
}

# Wait for a system service to become active
# Usage: wait_for_system_service service_name [max_wait_seconds]
wait_for_system_service() {
    local service=$1
    local max_wait=${2:-30}
    local count=0

    echo "  Waiting for $service to start..."
    while ! sudo systemctl is-active "$service" &>/dev/null; do
        sleep 1
        ((count++))
        if [ $count -ge $max_wait ]; then
            echo "  ⚠️  Service $service did not start within ${max_wait}s"
            return 1
        fi
    done
    echo "  ✓ Service $service is active"
    return 0
}

# Check if a user service is running
# Usage: is_user_service_active service_name
is_user_service_active() {
    local service=$1
    systemctl --user is-active "$service" &>/dev/null
}

# Check if a system service is running
# Usage: is_system_service_active service_name
is_system_service_active() {
    local service=$1
    sudo systemctl is-active "$service" &>/dev/null
}

# Create a systemd timer
# Usage: create_systemd_timer timer_name timer_file_path
create_systemd_timer() {
    local timer_name=$1
    local timer_file=$2

    echo "  Installing systemd timer: $timer_name"
    sudo cp "$timer_file" "/etc/systemd/system/$timer_name"
    sudo systemctl daemon-reload
    sudo systemctl enable "$timer_name"
    sudo systemctl start "$timer_name"
}

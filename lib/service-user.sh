#!/bin/bash
# shellcheck shell=bash
# Service user account creation and management for VPS services

# Create a system service user
# Usage: create_service_user username [homedir]
create_service_user() {
    local username=$1
    local homedir=${2:-/var/lib/$username}

    if id "$username" &>/dev/null; then
        echo "  ✓ User $username already exists"
        return 0
    fi

    echo "  Creating service user: $username"
    sudo useradd --system \
        --create-home \
        --home-dir "$homedir" \
        --shell /bin/false \
        "$username"
}

# Setup directories with proper permissions for a service
# Usage: setup_service_directories username dir1 [dir2 ...]
setup_service_directories() {
    local username=$1
    shift
    local dirs=("$@")

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            sudo mkdir -p "$dir"
        fi
        sudo chown "$username:$username" "$dir"
        sudo chmod 750 "$dir"
        echo "  ✓ Directory: $dir (owner: $username)"
    done
}

# Add user to a group (creates group if needed)
# Usage: add_user_to_group username groupname
add_user_to_group() {
    local username=$1
    local groupname=$2

    if ! getent group "$groupname" &>/dev/null; then
        echo "  Creating group: $groupname"
        sudo groupadd "$groupname"
    fi

    echo "  Adding $username to group $groupname"
    sudo usermod -a -G "$groupname" "$username"
}

# Set file permissions for service config
# Usage: set_service_file_permissions username filepath mode
set_service_file_permissions() {
    local username=$1
    local filepath=$2
    local mode=${3:-600}

    sudo chown "$username:$username" "$filepath"
    sudo chmod "$mode" "$filepath"
}

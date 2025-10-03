#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-folders.sh - Create folder structure based on profile
#
# Usage: ./setup-folders.sh [profile]
#   profile: minimal|desktop|server|gateway (default: desktop)

PROFILE="${1:-desktop}"

# Folder configuration
# Format: path:sync_type:profiles
# sync_type: none|syncthing
# profiles: comma-separated list of profiles that should have this folder
FOLDER_CONFIG=(
    "code/personal:syncthing:minimal,desktop,server,gateway"
    "code/work:syncthing:desktop,server,gateway"
    "code/forks:syncthing:desktop,gateway"
    "code/spikes:syncthing:desktop,gateway"
    "code/archive:syncthing:server,gateway"
    "Documents:syncthing:minimal,desktop,server,gateway"
    "Documents/notes:syncthing:minimal,desktop,server,gateway"
    "Documents/books:syncthing:desktop,gateway"
    "Documents/papers:syncthing:desktop,gateway"
    "Documents/personal:syncthing:desktop,gateway"
    "Photos:syncthing:desktop,gateway"
    "Photos/screenshots:none:desktop,gateway"
    "playground:syncthing:desktop,gateway"
    ".config:none:minimal,desktop,server,gateway"
    ".local/bin:none:minimal,desktop,server,gateway"
    ".local/share:none:minimal,desktop,server,gateway"
    ".local/state:none:minimal,desktop,server,gateway"
)

# Validate profile
validate_profile() {
    case "$PROFILE" in
        minimal|desktop|server|gateway)
            return 0
            ;;
        *)
            echo "❌ Invalid profile: $PROFILE"
            echo "   Valid profiles: minimal, desktop, server, gateway"
            exit 1
            ;;
    esac
}

# Check if folder should be created for profile
should_create() {
    local path=$1
    local sync_type=$2
    local profiles=$3

    # Check if current profile is in the folder's profile list
    if [[ ",$profiles," == *",$PROFILE,"* ]]; then
        return 0
    fi
    return 1
}

# Get folders by sync type for current profile
get_folders_by_sync_type() {
    local sync_filter=$1
    local folders=()

    for entry in "${FOLDER_CONFIG[@]}"; do
        IFS=':' read -r path sync_type profiles <<< "$entry"

        if should_create "$path" "$sync_type" "$profiles" && [ "$sync_type" = "$sync_filter" ]; then
            folders+=("$HOME/$path")
        fi
    done

    printf '%s\n' "${folders[@]}"
}

# Create folder structure
create_folders() {
    echo "    Creating folder structure for profile: $PROFILE"

    local created=0
    local skipped=0

    for entry in "${FOLDER_CONFIG[@]}"; do
        IFS=':' read -r path sync_type profiles <<< "$entry"

        if should_create "$path" "$sync_type" "$profiles"; then
            local full_path="$HOME/$path"

            if [ ! -d "$full_path" ]; then
                mkdir -p "$full_path"
                echo "      ✓ Created: $path"
                ((created++))
            else
                ((skipped++))
            fi
        fi
    done

    if [ $created -gt 0 ]; then
        echo "      Created $created folder(s), skipped $skipped existing"
    else
        echo "      All folders already exist"
    fi
}

# Show sync summary
show_sync_summary() {
    echo ""
    echo "    Sync configuration for '$PROFILE' profile:"

    local syncthing_folders
    mapfile -t syncthing_folders < <(get_folders_by_sync_type "syncthing")

    if [ ${#syncthing_folders[@]} -gt 0 ]; then
        echo "      Syncthing folders:"
        for folder in "${syncthing_folders[@]}"; do
            echo "        - ${folder/#$HOME/~}"
        done
    fi
}

# Main execution
main() {
    validate_profile
    create_folders
    show_sync_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

#!/bin/bash
# shellcheck shell=bash
# Backup utilities for scripts and interactive use

# Backup a single file with timestamp
# Usage: backup_path=$(backup_file filepath [backup_dir])
# Returns: Path to backup file
backup_file() {
    local file=$1
    local backup_dir=${2:-.}
    local timestamp=$(date +%Y%m%d-%H%M%S)

    if [ ! -f "$file" ]; then
        echo "Error: $file does not exist" >&2
        return 1
    fi

    local backup_name="$(basename "$file").bak.$timestamp"
    local backup_path="$backup_dir/$backup_name"

    cp "$file" "$backup_path"
    echo "$backup_path"
}

# Backup a directory as a compressed archive
# Usage: backup_archive=$(backup_directory dir [backup_dir])
# Returns: Path to backup archive
backup_directory() {
    local dir=$1
    local backup_dir=${2:-/var/backups}
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local basename=$(basename "$dir")

    if [ ! -d "$dir" ]; then
        echo "Error: $dir does not exist" >&2
        return 1
    fi

    sudo mkdir -p "$backup_dir"
    local archive_path="$backup_dir/${basename}-${timestamp}.tar.gz"
    sudo tar -czf "$archive_path" "$dir" 2>/dev/null

    echo "$archive_path"
}

# List backup files matching a pattern
# Usage: list_backups [pattern] [directory]
# Default pattern: *.bak.*
# Default directory: current directory
list_backups() {
    local pattern=${1:-*.bak.*}
    local dir=${2:-.}

    find "$dir" -name "$pattern" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | \
        cut -d' ' -f2-
}

# Restore a backup file
# Usage: restore_backup backup_file original_file
restore_backup() {
    local backup_file=$1
    local original_file=$2

    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file $backup_file does not exist" >&2
        return 1
    fi

    # Create a backup of the current file before restoring
    if [ -f "$original_file" ]; then
        local temp_backup
        temp_backup=$(backup_file "$original_file")
        echo "  Created safety backup: $temp_backup"
    fi

    cp "$backup_file" "$original_file"
    echo "  Restored: $original_file from $backup_file"
}

# Clean old backups (keep last N backups)
# Usage: clean_old_backups pattern [keep_count] [directory]
# Default keep_count: 10
# Default directory: current directory
clean_old_backups() {
    local pattern=$1
    local keep_count=${2:-10}
    local dir=${3:-.}

    local backups
    mapfile -t backups < <(list_backups "$pattern" "$dir")

    if [ ${#backups[@]} -le $keep_count ]; then
        echo "  Keeping all ${#backups[@]} backups (threshold: $keep_count)"
        return 0
    fi

    local to_delete=$((${#backups[@]} - keep_count))
    echo "  Removing $to_delete old backups (keeping newest $keep_count)"

    local deleted=0
    for ((i = keep_count; i < ${#backups[@]}; i++)); do
        rm -f "${backups[$i]}"
        ((deleted++))
    done

    echo "  Deleted $deleted old backup(s)"
}

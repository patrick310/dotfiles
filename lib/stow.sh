# shellcheck shell=bash

# Manage GNU Stow operations with conflict detection and rollback support.

discover_stow_packages() {
    local markers=()

    while IFS= read -r -d '' marker; do
        markers+=("$(dirname "$marker")")
    done < <(find "$DOTFILES_DIR" -maxdepth 2 -type f -name '.stow' -print0 | sort -z)

    if [ ${#markers[@]} -eq 0 ]; then
        echo "    Warning: No stow markers (*.stow) found." >&2
        return 0
    fi

    for dir in "${markers[@]}"; do
        printf '%s\n' "$(basename "$dir")"
    done
}

detect_conflicts() {
    local package=$1
    local conflicts=()

    local stow_output
    stow_output=$(stow --no --verbose=1 "$package" 2>&1)
    local stow_exit=$?
    stow_output=$(echo "$stow_output" | grep -v "BUG in find_stowed_path" || true)

    if [ $stow_exit -eq 0 ]; then
        return 0
    fi

    while IFS= read -r line; do
        if [[ $line =~ "over existing target" ]]; then
            local file
            file=$(echo "$line" | sed -n 's/.*over existing target \([^ ]*\).*/\1/p')
            conflicts+=("$file")
        elif [[ $line =~ "existing target is" ]]; then
            local file
            file=$(echo "$line" | sed -n 's/.*: \(.*\)$/\1/p')
            conflicts+=("$file")
        fi
    done <<< "$stow_output"

    printf '%s\n' "${conflicts[@]}"
    return 1
}

backup_conflicting_files() {
    local package=$1
    shift
    local conflicts=("$@")

    if [ ${#conflicts[@]} -eq 0 ]; then
        return 0
    fi

    echo "    ⚠️  Conflicts detected in package '$package':"
    for file in "${conflicts[@]}"; do
        echo "       ~/${file}"
    done

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would backup to: $BACKUP_DIR/"
        return 0
    fi

    if [ "$FORCE_MODE" = false ]; then
        echo
        echo "    Options:"
        echo "      1. Backup existing files and continue"
        echo "      2. Skip this package"
        echo "      3. Abort bootstrap"
        echo
        read -p "    Choose [1/2/3]: " choice

        case $choice in
            1) ;; # Continue
            2) return 1 ;;
            3)
                echo "❌ Bootstrap aborted by user"
                exit 1
                ;;
            *)
                echo "Invalid choice, aborting"
                exit 1
                ;;
        esac
    fi

    mkdir -p "$BACKUP_DIR"

    echo "    📦 Backing up conflicting files to: $BACKUP_DIR/"
    for file in "${conflicts[@]}"; do
        local source="$HOME/$file"
        local dest="$BACKUP_DIR/$file"

        if [ -f "$source" ] || [ -L "$source" ]; then
            mkdir -p "$(dirname "$dest")"
            mv "$source" "$dest"
            echo "       ✓ Backed up: $file"
        fi
    done

    return 0
}

is_stowed() {
    local package=$1
    grep -q "^$package$" "$STOW_STATE_FILE" 2>/dev/null
}

mark_stowed() {
    local package=$1
    echo "$package" >> "$STOW_STATE_FILE"
    STOWED_PACKAGES+=("$package")
}

rollback() {
    if [ ${#STOWED_PACKAGES[@]} -eq 0 ]; then
        return
    fi

    echo
    echo "❌ Error occurred, rolling back changes..."

    (cd "$DOTFILES_DIR" && for package in "${STOWED_PACKAGES[@]}"; do
        echo "    Unstowing: $package"
        stow --delete "$package" 2>&1 | grep -v "BUG in find_stowed_path" || true
        sed -i "/^$package$/d" "$STOW_STATE_FILE" 2>/dev/null || true
    done)

    if [ -d "$BACKUP_DIR" ]; then
        echo "    Restoring backups from: $BACKUP_DIR/"
        cp -r "$BACKUP_DIR"/. "$HOME/"
    fi

    echo "❌ Rollback complete"
}

stow_setup_trap() {
    trap rollback ERR
}

stow_package() {
    local package=$1

    if [ ! -d "$DOTFILES_DIR/$package" ]; then
        echo "    Warning: Package '$package' directory not found, skipping"
        return 0
    fi

    if is_stowed "$package"; then
        if [ "$DRY_RUN" = true ]; then
            echo "    $package: [DRY-RUN] would restow"
            return 0
        fi

        echo "    $package: already stowed, restowing..."
        local stow_output
        stow_output=$(stow --restow "$package" 2>&1)
        local stow_exit=$?
        stow_output=$(echo "$stow_output" | grep -v "BUG in find_stowed_path" || true)
        [ -n "$stow_output" ] && echo "$stow_output"

        if [ $stow_exit -ne 0 ]; then
            echo "    ❌ Failed to restow $package"
            return 1
        fi
        return 0
    fi

    local conflict_list
    if ! conflict_list=$(detect_conflicts "$package"); then
        local conflicts
        mapfile -t conflicts <<< "$conflict_list"

        if ! backup_conflicting_files "$package" "${conflicts[@]}"; then
            echo "    ⏭️  Skipping package: $package"
            return 0
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "    $package: [DRY-RUN] would stow"
        return 0
    fi

    echo "    $package: stowing..."
    local stow_output
    stow_output=$(stow "$package" 2>&1)
    local stow_exit=$?
    stow_output=$(echo "$stow_output" | grep -v "BUG in find_stowed_path" || true)
    [ -n "$stow_output" ] && echo "$stow_output"

    if [ $stow_exit -eq 0 ]; then
        mark_stowed "$package"
        echo "       ✓ Success"
    else
        echo "    ❌ Failed to stow $package"
        return 1
    fi
}

stow_dotfiles() {
    local packages=()
    if [ $# -gt 0 ]; then
        packages=("$@")
    else
        mapfile -t packages < <(discover_stow_packages)
    fi

    if [ ${#packages[@]} -eq 0 ]; then
        echo "    No stow packages discovered"
        return 0
    fi

    echo "==> Stowing configurations..."

    (cd "$DOTFILES_DIR" && for package in "${packages[@]}"; do
        stow_package "$package"
    done)
}

# shellcheck shell=bash

# Distribution package installation helpers.

install_profile_packages() {
    local installer="$DOTFILES_DIR/install/$OS.sh"

    if [ ! -f "$installer" ] || [ ! -s "$installer" ]; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "==> [DRY-RUN] Would run $OS-specific package installation for profile '$PROFILE'"
        return
    fi

    echo "==> Running $OS-specific package installation (profile: $PROFILE)..."
    BOOTSTRAP_PROFILE="$PROFILE" bash "$installer" "$PROFILE"
}

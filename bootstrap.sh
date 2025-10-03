#!/usr/bin/env bash
# ~/dotfiles/bootstrap.sh - Idempotent dotfiles setup with conflict handling

set -eo pipefail  # Exit on error, pipe failures

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_STATE_FILE="$DOTFILES_DIR/.stow_state"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
STOWED_PACKAGES=()


# Parse command-line arguments
FORCE_MODE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: ./bootstrap.sh [OPTIONS]

Options:
  --force, -f       Auto-backup conflicting files without prompting
  --dry-run, -n     Show what would happen without making changes
  --help, -h        Show this help message

Examples:
  ./bootstrap.sh              # Interactive mode
  ./bootstrap.sh --force      # Auto-backup conflicts
  ./bootstrap.sh --dry-run    # Preview changes
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    # Normalize OS name for script lookup
    case "$ID" in
        opensuse*) OS="opensuse" ;;
        ubuntu|debian) OS="ubuntu" ;;
        fedora) OS="fedora" ;;
        *) OS="$ID" ;;
    esac
else
    echo "Warning: Could not detect OS"
    OS="unknown"
fi

# Install prerequisites if missing
install_prerequisites() {
    echo "==> Checking prerequisites..."

    local packages_needed=false
    command -v stow &> /dev/null || packages_needed=true
    command -v git &> /dev/null || packages_needed=true

    if [ "$packages_needed" = false ]; then
        echo "    Prerequisites already installed"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would install: stow git"
        return
    fi

    echo "    Installing stow and git..."
    case $OS in
        ubuntu|debian)
            sudo apt update && sudo apt install -y stow git
            ;;
        opensuse*)
            sudo zypper install -y stow git
            ;;
        fedora)
            sudo dnf install -y stow git
            ;;
        *)
            echo "    Warning: Unknown OS, please install stow and git manually"
            return 1
            ;;
    esac
}

# Create necessary directories (idempotent)
create_directories() {
    echo "==> Creating config directories..."

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would create: ~/.config/bash ~/.local/bin ~/.local/share ~/.cache"
        return
    fi

    mkdir -p ~/.config/bash
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/share
    mkdir -p ~/.cache

    mkdir -p ~/code/work
    mkdir -p ~/code/forks
    mkdir -p ~/code/spikes
    mkdir -p ~/code/personal

    mkdir -p ~/tmp

    mkdir -p ~/Downloads

    
}

# Detect stow conflicts for a package
detect_conflicts() {
    local package=$1
    local conflicts=()

    # Run stow in simulation mode to detect conflicts
    local stow_output
    stow_output=$(stow --no --verbose=1 "$package" 2>&1)
    local stow_exit=$?
    stow_output=$(echo "$stow_output" | grep -v "BUG in find_stowed_path" || true)

    if [ $stow_exit -eq 0 ]; then
        return 0  # No conflicts
    else
        # Parse conflict messages
        while IFS= read -r line; do
            if [[ $line =~ "over existing target" ]]; then
                # Extract filename: "over existing target .profile since..."
                local file=$(echo "$line" | sed -n 's/.*over existing target \([^ ]*\).*/\1/p')
                conflicts+=("$file")
            elif [[ $line =~ "existing target is" ]]; then
                # Older stow format: "existing target is: .profile"
                local file=$(echo "$line" | sed -n 's/.*: \(.*\)$/\1/p')
                conflicts+=("$file")
            fi
        done <<< "$stow_output"

        # Return conflicts via global array (bash limitation workaround)
        printf '%s\n' "${conflicts[@]}"
        return 1
    fi
}

# Backup conflicting files
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

    # Ask user what to do (unless --force)
    if [ "$FORCE_MODE" = false ]; then
        echo
        echo "    Options:"
        echo "      1. Backup existing files and continue"
        echo "      2. Skip this package"
        echo "      3. Abort bootstrap"
        echo
        read -p "    Choose [1/2/3]: " choice

        case $choice in
            1) ;; # Continue with backup
            2) return 1 ;; # Skip package
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

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Backup each conflicting file
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

# Check if a package is already stowed
is_stowed() {
    local package=$1
    grep -q "^$package$" "$STOW_STATE_FILE" 2>/dev/null
}

# Mark a package as stowed
mark_stowed() {
    local package=$1
    echo "$package" >> "$STOW_STATE_FILE"
    STOWED_PACKAGES+=("$package")
}

# Rollback stowed packages on error
rollback() {
    if [ ${#STOWED_PACKAGES[@]} -eq 0 ]; then
        return
    fi

    echo
    echo "❌ Error occurred, rolling back changes..."

    cd "$DOTFILES_DIR"
    for package in "${STOWED_PACKAGES[@]}"; do
        echo "    Unstowing: $package"
        stow --delete "$package" 2>&1 | grep -v "BUG in find_stowed_path" || true
        # Remove from state file
        sed -i "/^$package$/d" "$STOW_STATE_FILE" 2>/dev/null || true
    done

    # Restore backed up files if they exist
    if [ -d "$BACKUP_DIR" ]; then
        echo "    Restoring backups from: $BACKUP_DIR/"
        cp -r "$BACKUP_DIR"/. "$HOME/"
    fi

    echo "❌ Rollback complete"
}

# Set trap for rollback on error
trap rollback ERR

# Stow a package with conflict handling
stow_package() {
    local package=$1

    if [ ! -d "$DOTFILES_DIR/$package" ]; then
        echo "    Warning: Package '$package' directory not found, skipping"
        return 0
    fi

    # Check if already stowed
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

    # Detect conflicts
    local conflict_list
    if ! conflict_list=$(detect_conflicts "$package"); then
        # Conflicts found
        local conflicts
        mapfile -t conflicts <<< "$conflict_list"

        # Backup conflicting files
        if ! backup_conflicting_files "$package" "${conflicts[@]}"; then
            echo "    ⏭️  Skipping package: $package"
            return 0
        fi
    fi

    # Stow the package
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

# Stow configurations
stow_dotfiles() {
    echo "==> Stowing configurations..."
    cd "$DOTFILES_DIR"

    # Stow each package
    stow_package "shell"
    stow_package "nvim"
    stow_package "kde"
    stow_package "blesh"
}

# Ensure bashrc sources our config (idempotent)
configure_bashrc() {
    if grep -q ".config/bash/bashrc" ~/.bashrc 2>/dev/null; then
        echo "==> .bashrc already configured"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "==> [DRY-RUN] Would configure .bashrc to source custom config"
        return
    fi

    echo "==> Configuring .bashrc to source custom config..."
    cat >> ~/.bashrc << 'EOF'

# Source custom bash configuration
[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc
EOF
}

# Install distro-specific packages
install_packages() {
    if [ -f "$DOTFILES_DIR/install/$OS.sh" ] && [ -s "$DOTFILES_DIR/install/$OS.sh" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "==> [DRY-RUN] Would run $OS-specific package installation"
            return
        fi

        echo "==> Running $OS-specific package installation..."
        bash "$DOTFILES_DIR/install/$OS.sh"
    fi
}

# Run setup scripts
run_setup_scripts() {
    echo "==> Running setup scripts..."

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would run setup scripts"
        return
    fi

    # KDE setup (only if running KDE)
    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && [ -f "$DOTFILES_DIR/scripts/setup-kde.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-kde.sh"
    fi

    # Secrets setup (only if private-dots exists and script exists)
    if [ -d "$HOME/private-dots" ] && [ -f "$DOTFILES_DIR/scripts/setup-secrets.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-secrets.sh"
    fi
}

# Main execution
main() {
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 DRY-RUN MODE - No changes will be made"
        echo
    fi

    echo "🔧 Bootstrapping dotfiles..."
    echo

    install_prerequisites
    create_directories
    stow_dotfiles
    configure_bashrc
    install_packages
    run_setup_scripts

    # Disable trap after successful completion
    trap - ERR

    echo
    if [ "$DRY_RUN" = true ]; then
        echo "✅ Dry-run complete! Run without --dry-run to apply changes."
    else
        echo "✅ Bootstrap complete!"

        if [ -d "$BACKUP_DIR" ]; then
            echo "📦 Backed up files: $BACKUP_DIR/"
        fi

        echo ""
        echo "📝 Next steps:"
        echo "   1. Reload shell: source ~/.bashrc"
        if [ -d "$HOME/private-dots" ]; then
            echo "   2. Setup home folders & sync: ~/private-dots/setup-home.sh"
        fi
        echo ""
        echo "💡 For quick server setup, you're done! Skip step 2."
    fi
}

main "$@"

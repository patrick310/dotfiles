#!/usr/bin/env bash
# ~/dotfiles/bootstrap.sh - Idempotent dotfiles setup with conflict handling

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$DOTFILES_DIR/lib"
STOW_STATE_FILE="$DOTFILES_DIR/.stow_state"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
STOWED_PACKAGES=()

DEFAULT_PROFILE="${BOOTSTRAP_PROFILE:-desktop}"
PROFILE="$DEFAULT_PROFILE"
FORCE_MODE=false
DRY_RUN=false

# shellcheck source=lib/prereqs.sh
source "$LIB_DIR/prereqs.sh"
# shellcheck source=lib/stow.sh
source "$LIB_DIR/stow.sh"
# shellcheck source=lib/packages.sh
source "$LIB_DIR/packages.sh"

usage() {
    cat <<'HELP'
Usage: ./bootstrap.sh [OPTIONS]

Options:
  --profile, -p NAME  Use profile NAME (default: desktop)
  --force,   -f       Auto-backup conflicting files without prompting
  --dry-run,  -n      Show what would happen without making changes
  --help,    -h       Show this help message

Examples:
  ./bootstrap.sh                     # Interactive mode
  ./bootstrap.sh --profile server    # Server profile
  ./bootstrap.sh --force --dry-run   # Preview with forced backups
HELP
}

detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
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
}

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
    cat >> ~/.bashrc <<'RC'

# Source custom bash configuration
[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc
RC
}

run_setup_scripts() {
    echo "==> Running setup scripts..."

    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] Would run setup scripts"
        return
    fi

    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && [ -f "$DOTFILES_DIR/scripts/setup-kde.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-kde.sh"
    fi

    if [ -f "$DOTFILES_DIR/scripts/setup-rust.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-rust.sh"
    fi

    if [ -d "$HOME/private-dots" ] && [ -f "$DOTFILES_DIR/scripts/setup-secrets.sh" ]; then
        bash "$DOTFILES_DIR/scripts/setup-secrets.sh"
    fi
}

print_summary() {
    echo
    if [ "$DRY_RUN" = true ]; then
        echo "✅ Dry-run complete! Run without --dry-run to apply changes."
        return
    fi

    echo "✅ Bootstrap complete!"

    if [ -d "$BACKUP_DIR" ]; then
        echo "📦 Backed up files: $BACKUP_DIR/"
    fi

    echo
    echo "📝 Next steps:"
    echo "   1. Reload shell: source ~/.bashrc"
    if [ -d "$HOME/private-dots" ]; then
        echo "   2. Setup home folders & sync: ~/private-dots/setup-home.sh"
    fi
    echo
    echo "Profile applied: $PROFILE"
}

parse_args() {
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
            --profile|-p)
                if [[ -z ${2:-} ]]; then
                    echo "Error: --profile requires a value" >&2
                    exit 1
                fi
                PROFILE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    detect_os

    if [ "$DRY_RUN" = true ]; then
        echo "🔍 DRY-RUN MODE - No changes will be made"
        echo
    fi

    echo "🔧 Bootstrapping dotfiles (profile: $PROFILE)..."
    echo

    ensure_prerequisites
    ensure_user_directories

    stow_setup_trap
    stow_dotfiles

    configure_bashrc
    install_profile_packages
    run_setup_scripts

    trap - ERR
    print_summary
}

main "$@"

# shellcheck shell=bash

# Distribution package installation helpers.

# shellcheck disable=SC2034  # referenced after sourcing this file
COLLECTED_PACKAGES=()
# shellcheck disable=SC2034  # referenced after sourcing this file
MAPPED_PACKAGES=()

_lp_read_package_file() {
    local file=$1
    [[ -f $file ]] || return 0

    while IFS= read -r line; do
        [[ -z $line || $line =~ ^# ]] && continue
        COLLECTED_PACKAGES+=("$line")
    done < "$file"
}

collect_packages_for_profile() {
    local profile=${1:-desktop}

    COLLECTED_PACKAGES=()

    _lp_read_package_file "$DOTFILES_DIR/install/common.txt"

    local profile_file="$DOTFILES_DIR/install/profiles/${profile}.txt"
    if [ -f "$profile_file" ]; then
        _lp_read_package_file "$profile_file"
    else
        echo "⚠️  Profile package list not found: install/profiles/${profile}.txt" >&2
    fi

    # Dedupe while preserving order
    declare -A seen=()
    local deduped=()
    for pkg in "${COLLECTED_PACKAGES[@]}"; do
        if [[ -n $pkg && -z ${seen[$pkg]+x} ]]; then
            deduped+=("$pkg")
            seen[$pkg]=1
        fi
    done
    COLLECTED_PACKAGES=("${deduped[@]}")
}

map_packages_for_os() {
    local os=${1:-$OS}
    local mapped=()

    for pkg in "${COLLECTED_PACKAGES[@]}"; do
        local translated=$pkg
        case $os in
            fedora)
                case $pkg in
                    dnsutils) translated="bind-utils" ;;
                esac
                ;;
            opensuse*)
                case $pkg in
                    fd-find) translated="fd" ;;
                    g++) translated="gcc-c++" ;;
                    dnsutils) translated="bind-utils" ;;
                    nodejs) translated="nodejs-default" ;;
                    npm) translated="npm-default" ;;
                    shellcheck) translated="ShellCheck" ;;
                esac
                ;;
            *)
                ;;
        esac
        mapped+=("$translated")
    done

    MAPPED_PACKAGES=("${mapped[@]}")
}

install_profile_packages() {
    local installer="$DOTFILES_DIR/install/$OS.sh"

    if [ ! -f "$installer" ] || [ ! -s "$installer" ]; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        # shellcheck disable=SC2153
        echo "==> [DRY-RUN] Would run $OS-specific package installation for profile '$PROFILE'"
        return
    fi

    echo "==> Running $OS-specific package installation (profile: $PROFILE)..."
    BOOTSTRAP_PROFILE="$PROFILE" bash "$installer" "$PROFILE"
}

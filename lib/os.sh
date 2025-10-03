# shellcheck shell=bash

# Detect the host OS and normalize to installer script names.

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
        echo "Warning: Could not detect OS" >&2
        OS="unknown"
    fi
}

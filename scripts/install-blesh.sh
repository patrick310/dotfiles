#!/usr/bin/env bash
# ~/dotfiles/scripts/install-blesh.sh - Install or update ble.sh under ~/.local

set -euo pipefail

BLE_SH_REPO="${BLE_SH_REPO:-https://github.com/akinomyoga/ble.sh.git}"
BLE_SRC_DIR="${BLE_SRC_DIR:-$HOME/.local/src/blesh}"
BLE_INSTALL_PREFIX="${BLE_INSTALL_PREFIX:-$HOME/.local}"

install_ble_sh() {
    local repo_url=${1:-$BLE_SH_REPO}
    local src_dir=${2:-$BLE_SRC_DIR}

    mkdir -p "$(dirname "$src_dir")"

    if [ ! -d "$src_dir/.git" ]; then
        echo "==> Cloning ble.sh into $src_dir"
        git clone --recursive "$repo_url" "$src_dir"
    else
        echo "==> Updating existing ble.sh clone"
        git -C "$src_dir" fetch --tags --prune
        git -C "$src_dir" pull --ff-only
        git -C "$src_dir" submodule update --init --recursive
    fi

    echo "==> Building and installing ble.sh"
    make -C "$src_dir" install PREFIX="${BLE_INSTALL_PREFIX}"

    echo "==> ble.sh installed to ${BLE_INSTALL_PREFIX}/share/blesh"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    install_ble_sh "$@"
fi

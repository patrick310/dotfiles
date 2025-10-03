#!/usr/bin/env bash
# Ensure a usable Rust toolchain via rustup

set -euo pipefail

if ! command -v rustup &> /dev/null; then
    echo "    rustup not installed, skipping rust toolchain setup"
    exit 0
fi

if rustup show active-toolchain &> /dev/null; then
    echo "    rustup toolchain already configured"
    exit 0
fi

echo "    Installing stable Rust toolchain via rustup..."
rustup install stable
rustup default stable

echo "    ✓ Rust stable toolchain ready"

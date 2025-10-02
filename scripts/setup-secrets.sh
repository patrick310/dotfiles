#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-secrets.sh - Bootstrap private dotfiles and secrets

if [ ! -d "$HOME/private-dots" ]; then
    echo "    No private-dots directory found, skipping secrets setup"
    exit 0
fi

echo "    Setting up private dotfiles and secrets..."

# Check if private-dots has a bootstrap script
if [ -f "$HOME/private-dots/bootstrap.sh" ]; then
    echo "      Running private-dots bootstrap..."
    bash "$HOME/private-dots/bootstrap.sh"
else
    echo "      Warning: private-dots/bootstrap.sh not found"
fi

# Check if Bitwarden CLI is installed
if command -v bw &> /dev/null; then
    echo "      ✓ Bitwarden CLI detected"
    echo "      Run 'bw login' to authenticate with Bitwarden"
else
    echo "      Note: Bitwarden CLI not installed"
    echo "      Install with: sudo snap install bw (or check install scripts)"
fi

echo "      ✓ Secrets setup complete"

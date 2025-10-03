#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-caddy.sh - Setup Caddy reverse proxy
#
# This script sets up Caddy as a reverse proxy for services like Headscale,
# with automatic HTTPS via Let's Encrypt

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIVATE_DOTS_DIR="${PRIVATE_DOTS_DIR:-$HOME/private-dots}"

# Source libraries
# shellcheck source=lib/backup.sh
source "$DOTFILES_DIR/lib/backup.sh"

# Check if Caddy is installed
check_caddy_installed() {
    if command -v caddy &>/dev/null; then
        local version
        version=$(caddy version 2>/dev/null | head -1)
        echo "  ✓ Caddy already installed ($version)"
        return 0
    fi
    return 1
}

# Install Caddy
install_caddy() {
    echo "  Installing Caddy..."

    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                echo "  Installing via apt repository..."
                sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
                sudo apt update
                sudo apt install -y caddy
                ;;
            fedora)
                echo "  Installing via dnf..."
                sudo dnf install -y 'dnf-command(copr)'
                sudo dnf copr enable -y @caddy/caddy
                sudo dnf install -y caddy
                ;;
            *)
                echo "  ⚠️  Unsupported OS, attempting generic install..."
                # Download binary directly
                local arch
                arch=$(uname -m)
                case "$arch" in
                    x86_64) arch="amd64" ;;
                    aarch64) arch="arm64" ;;
                    *) echo "  ❌ Unsupported architecture: $arch"; return 1 ;;
                esac

                curl -sL "https://caddyserver.com/api/download?os=linux&arch=${arch}" -o /tmp/caddy
                sudo install -m 755 /tmp/caddy /usr/local/bin/caddy
                rm /tmp/caddy

                # Create systemd service manually
                sudo tee /etc/systemd/system/caddy.service >/dev/null <<'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
                # Create caddy user
                sudo groupadd --system caddy 2>/dev/null || true
                sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy 2>/dev/null || true
                ;;
        esac
    fi

    echo "  ✓ Caddy installed: $(caddy version | head -1)"
}

# Deploy Caddyfile
deploy_caddyfile() {
    echo "  Deploying Caddyfile..."

    local config_source="$PRIVATE_DOTS_DIR/caddy/Caddyfile"
    local config_dest="/etc/caddy/Caddyfile"

    if [ ! -f "$config_source" ]; then
        echo "  ⚠️  Caddyfile not found: $config_source"
        echo "  💡 Caddyfile should be in private-dots/caddy/"
        return 1
    fi

    # Create /etc/caddy directory
    sudo mkdir -p /etc/caddy

    # Backup existing config if present
    if [ -f "$config_dest" ]; then
        backup_file "$config_dest" "/var/backups"
        echo "  ✓ Backed up existing Caddyfile"
    fi

    # Copy configuration
    sudo cp "$config_source" "$config_dest"
    sudo chown root:root "$config_dest"
    sudo chmod 644 "$config_dest"

    echo "  ✓ Caddyfile deployed to $config_dest"
}

# Setup log directory
setup_logging() {
    echo "  Setting up logging..."

    sudo mkdir -p /var/log/caddy
    sudo chown caddy:caddy /var/log/caddy
    sudo chmod 750 /var/log/caddy

    echo "  ✓ Log directory created"
}

# Validate Caddyfile
validate_config() {
    echo "  Validating Caddyfile..."

    if sudo caddy validate --config /etc/caddy/Caddyfile 2>&1; then
        echo "  ✓ Caddyfile is valid"
        return 0
    else
        echo "  ❌ Caddyfile validation failed"
        return 1
    fi
}

# Setup firewall
setup_firewall() {
    echo "  Configuring firewall..."

    if ! command -v ufw &>/dev/null; then
        echo "  ⚠️  ufw not installed, skipping firewall configuration"
        return 0
    fi

    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp comment 'Caddy HTTP (ACME challenge)'
    sudo ufw allow 443/tcp comment 'Caddy HTTPS'

    echo "  ✓ Firewall configured (ports 80, 443)"
}

# Show instructions
show_instructions() {
    echo ""
    echo "  📝 Next Steps:"
    echo ""
    echo "  1. Ensure DNS is configured:"
    echo "     - mesh.weber.us.org → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
    echo ""
    echo "  2. Start Caddy service:"
    echo "     sudo systemctl start caddy"
    echo ""
    echo "  3. Check status:"
    echo "     sudo systemctl status caddy"
    echo "     sudo journalctl -u caddy -f"
    echo ""
    echo "  4. Caddy will automatically obtain Let's Encrypt certificates"
    echo ""
    echo "  5. Test HTTPS:"
    echo "     curl -I https://mesh.weber.us.org"
    echo ""
    echo "  6. View logs:"
    echo "     sudo tail -f /var/log/caddy/mesh.weber.us.org.log"
    echo ""
    echo "  7. Reload config after changes:"
    echo "     sudo systemctl reload caddy"
    echo ""
}

# Main execution
main() {
    echo "==> Setting up Caddy Reverse Proxy"

    # Install if not present
    if ! check_caddy_installed; then
        install_caddy
    fi

    deploy_caddyfile
    setup_logging

    if ! validate_config; then
        echo "❌ Caddyfile validation failed, not starting service"
        exit 1
    fi

    setup_firewall

    # Enable and start service
    echo "  Enabling Caddy service..."
    sudo systemctl daemon-reload
    sudo systemctl enable caddy

    show_instructions

    echo ""
    echo "✅ Caddy setup complete!"
    echo ""
    echo "🚀 To start Caddy and enable HTTPS:"
    echo "   sudo systemctl start caddy"
}

main "$@"

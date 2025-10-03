#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-headscale.sh - Setup Headscale VPN server
#
# This script sets up Headscale (open source Tailscale control server)
# with proper service user, systemd hardening, and security configuration

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
# shellcheck source=lib/service-user.sh
source "$DOTFILES_DIR/lib/service-user.sh"
# shellcheck source=lib/systemd.sh
source "$DOTFILES_DIR/lib/systemd.sh"
# shellcheck source=lib/backup.sh
source "$DOTFILES_DIR/lib/backup.sh"

HEADSCALE_VERSION="${HEADSCALE_VERSION:-0.26.1}"
HEADSCALE_USER="headscale"
NAMESPACE="${HEADSCALE_NAMESPACE:-default}"

# Check if headscale is already installed
check_headscale_installed() {
    if command -v headscale &>/dev/null; then
        local version
        version=$(headscale version 2>/dev/null | grep -oP 'v\K[0-9.]+' || echo "unknown")
        echo "  ✓ Headscale already installed (version: $version)"
        return 0
    fi
    return 1
}

# Install headscale binary
install_headscale() {
    echo "  Installing Headscale v${HEADSCALE_VERSION}..."

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *)
            echo "  ⚠️  Unsupported architecture: $arch"
            return 1
            ;;
    esac

    local url="https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_linux_${arch}"

    echo "  Downloading from: $url"
    curl -sL "$url" -o /tmp/headscale

    sudo install -m 755 /tmp/headscale /usr/local/bin/headscale
    rm /tmp/headscale

    echo "  ✓ Headscale installed: $(headscale version | head -1)"
}

# Setup service user and directories
setup_service_user() {
    echo "  Setting up headscale service user..."

    create_service_user "$HEADSCALE_USER" "/var/lib/$HEADSCALE_USER"

    # Create required directories
    setup_service_directories "$HEADSCALE_USER" \
        "/etc/headscale" \
        "/var/lib/headscale" \
        "/var/log/headscale"

    # Create runtime directory (in /run, not /var/run)
    sudo mkdir -p /run/headscale
    sudo chown "$HEADSCALE_USER:$HEADSCALE_USER" /run/headscale
    sudo chmod 755 /run/headscale
}

# Deploy configuration
deploy_config() {
    echo "  Deploying headscale configuration..."

    local config_source="$DOTFILES_DIR/headscale/config.yaml"
    local config_dest="/etc/headscale/config.yaml"

    if [ ! -f "$config_source" ]; then
        echo "  ⚠️  Config not found: $config_source"
        return 1
    fi

    # Backup existing config if present
    if [ -f "$config_dest" ]; then
        backup_file "$config_dest" "/var/backups"
        echo "  ✓ Backed up existing config"
    fi

    # Copy and set permissions
    sudo cp "$config_source" "$config_dest"
    set_service_file_permissions "$HEADSCALE_USER" "$config_dest" 640

    echo "  ✓ Configuration deployed to $config_dest"
    echo "  💡 Customize server_url and other settings in $config_dest"
}

# Create systemd service
create_systemd_service() {
    echo "  Creating systemd service..."

    local service_file="/etc/systemd/system/headscale.service"

    # Backup existing service if present
    if [ -f "$service_file" ]; then
        backup_file "$service_file" "/var/backups"
    fi

    sudo tee "$service_file" >/dev/null <<'EOF'
[Unit]
Description=Headscale VPN Control Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=headscale
Group=headscale

ExecStart=/usr/local/bin/headscale serve
Restart=always
RestartSec=5

# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/headscale /var/run/headscale /var/log/headscale
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateDevices=true
ProtectClock=true

# Process limits
LimitNOFILE=65536
LimitNPROC=512

[Install]
WantedBy=multi-user.target
EOF

    echo "  ✓ Systemd service created with security hardening"
}

# Setup firewall
setup_firewall() {
    echo "  Configuring firewall..."

    if ! command -v ufw &>/dev/null; then
        echo "  ⚠️  ufw not installed, skipping firewall configuration"
        return 0
    fi

    # NOTE: When using Caddy reverse proxy:
    # - Headscale listens on localhost:8080 (no external access needed)
    # - Caddy handles external HTTPS on port 443
    # - Firewall is configured by setup-caddy.sh (ports 80, 443)

    # DERP relay (if embedded DERP is enabled)
    # sudo ufw allow 3478/udp comment 'Headscale DERP STUN'

    # WireGuard (if clients use default port)
    # sudo ufw allow 41641/udp comment 'WireGuard'

    echo "  ✓ Firewall: No changes needed (Caddy will handle external traffic)"
    echo "  💡 Run setup-caddy.sh to configure ports 80/443"
}

# Initialize database
initialize_database() {
    echo "  Initializing database..."

    # Run database migration
    if sudo -u "$HEADSCALE_USER" headscale db migrate &>/dev/null; then
        echo "  ✓ Database initialized"
    else
        echo "  ⚠️  Database migration may have failed"
    fi
}

# Create initial user (replaces namespace in v0.23+)
create_user() {
    local username="${HEADSCALE_USER_NAME:-default}"

    echo "  Creating initial user: $username"

    # Check if user exists
    if sudo -u "$HEADSCALE_USER" headscale users list 2>/dev/null | grep -q "^$username"; then
        echo "  ✓ User '$username' already exists"
    else
        if sudo -u "$HEADSCALE_USER" headscale users create "$username" &>/dev/null; then
            echo "  ✓ User '$username' created"
        else
            echo "  ⚠️  Failed to create user (may need manual creation)"
        fi
    fi
}

# Show enrollment instructions
show_instructions() {
    echo ""
    echo "  📝 Next Steps:"
    echo ""
    echo "  1. Set up Caddy reverse proxy (REQUIRED for HTTPS):"
    echo "     ~/dotfiles/scripts/setup-caddy.sh"
    echo ""
    echo "  2. Update headscale config with your domain:"
    echo "     sudo nano /etc/headscale/config.yaml"
    echo "     - Set server_url: https://your-domain.com"
    echo "     - Update dns.base_domain if needed"
    echo ""
    echo "  3. Restart headscale after config changes:"
    echo "     sudo systemctl restart headscale"
    echo ""
    echo "  4. Create a pre-auth key for device enrollment:"
    echo "     # First, list users to get the user ID:"
    echo "     sudo -u headscale headscale users list"
    echo "     # Then create key using the numeric ID:"
    echo "     sudo -u headscale headscale preauthkeys create --user 1 -e 24h"
    echo ""
    echo "  5. On client devices, install Tailscale and connect:"
    echo "     tailscale up --login-server https://your-domain.com --authkey YOUR_KEY"
    echo ""
    echo "  6. List connected devices:"
    echo "     sudo -u headscale headscale nodes list"
    echo ""
    echo "  7. Check service status:"
    echo "     sudo systemctl status headscale"
    echo "     sudo journalctl -u headscale -f"
    echo ""
    echo "  📚 Documentation:"
    echo "     - https://headscale.net/docs/"
    echo "     - ~/dotfiles/docs/services.md"
    echo ""
}

# Main execution
main() {
    echo "==> Setting up Headscale VPN Server"

    # Check if running on a server/gateway
    if [ "$(hostname)" != "gateway" ] && [ "$FORCE" != "true" ]; then
        echo "  ⚠️  This script is typically run on a gateway/VPS server"
        echo "  💡 Set FORCE=true to install anyway"
        read -r -p "  Continue? (y/N) " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "  Cancelled"
            exit 0
        fi
    fi

    # Install if not present
    if ! check_headscale_installed; then
        install_headscale
    fi

    setup_service_user
    deploy_config
    create_systemd_service
    setup_firewall

    # Start service
    echo "  Starting headscale service..."
    sudo systemctl daemon-reload
    sudo systemctl enable headscale
    sudo systemctl start headscale

    # Wait for service to start
    if wait_for_system_service "headscale.service" 10; then
        initialize_database
        create_user
        show_instructions

        echo "✅ Headscale VPN setup complete!"
    else
        echo "❌ Headscale service failed to start"
        echo "   Check logs: sudo journalctl -u headscale -n 50"
        exit 1
    fi
}

main "$@"

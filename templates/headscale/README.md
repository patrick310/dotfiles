# Headscale VPN Server Setup

Self-hosted Tailscale control server for private mesh VPN.

## Prerequisites

```bash
# Install dependencies
sudo apt install curl

# You'll also need Caddy for HTTPS reverse proxy
# See ../caddy/README.md
```

## Install Headscale

1. **Download latest release:**
   ```bash
   VERSION="0.26.1"  # Check https://github.com/juanfont/headscale/releases
   ARCH="amd64"      # or arm64

   curl -sL "https://github.com/juanfont/headscale/releases/download/v${VERSION}/headscale_${VERSION}_linux_${ARCH}" \
     -o /tmp/headscale

   sudo install -m 755 /tmp/headscale /usr/local/bin/headscale
   rm /tmp/headscale
   ```

2. **Create service user:**
   ```bash
   sudo useradd --system --user-group --create-home \
     --home-dir /var/lib/headscale headscale
   ```

3. **Create directories:**
   ```bash
   sudo mkdir -p /etc/headscale /var/lib/headscale /var/log/headscale /run/headscale
   sudo chown headscale:headscale /var/lib/headscale /var/log/headscale /run/headscale
   ```

## Configure

1. **Copy config from this repo:**
   ```bash
   sudo cp ~/dotfiles/headscale/config.yaml /etc/headscale/config.yaml
   sudo chown headscale:headscale /etc/headscale/config.yaml
   sudo chmod 640 /etc/headscale/config.yaml
   ```

2. **Edit config:**
   ```bash
   sudo nano /etc/headscale/config.yaml
   ```

   Update:
   - `server_url: https://your-domain.com`
   - `dns.base_domain: your-domain.com` (optional)

## Create Systemd Service

Create `/etc/systemd/system/headscale.service`:

```ini
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

# Security hardening
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

LimitNOFILE=65536
LimitNPROC=512

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now headscale
```

## Initialize

1. **Run database migration:**
   ```bash
   sudo -u headscale headscale db migrate
   ```

2. **Create initial user:**
   ```bash
   sudo -u headscale headscale users create default
   ```

3. **List users to get ID:**
   ```bash
   sudo -u headscale headscale users list
   ```

## Enroll Devices

1. **Create pre-auth key:**
   ```bash
   sudo -u headscale headscale preauthkeys create --user 1 -e 24h
   ```

2. **On client devices, install Tailscale:**
   ```bash
   # See https://tailscale.com/download

   # Connect to your headscale server
   sudo tailscale up --login-server https://your-domain.com --authkey YOUR_KEY
   ```

3. **List connected devices:**
   ```bash
   sudo -u headscale headscale nodes list
   ```

## Firewall

If using UFW and Caddy:
```bash
# Caddy handles HTTPS on port 443
sudo ufw allow 80/tcp   # ACME challenge
sudo ufw allow 443/tcp  # HTTPS

# Optional: DERP relay
# sudo ufw allow 3478/udp

# Optional: WireGuard
# sudo ufw allow 41641/udp
```

## Monitor

```bash
# Service status
sudo systemctl status headscale

# Logs
sudo journalctl -u headscale -f

# Connected devices
sudo -u headscale headscale nodes list

# Users
sudo -u headscale headscale users list
```

## Notes

- Headscale listens on `localhost:8080` by default
- Use Caddy to reverse proxy HTTPS (see `../caddy/README.md`)
- DNS A record must point to your server's IP
- Let's Encrypt needs ports 80/443 accessible
- See config file in `~/dotfiles/headscale/config.yaml` for reference

## Documentation

- https://headscale.net/docs/
- https://github.com/juanfont/headscale

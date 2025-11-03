# Caddy Reverse Proxy Setup

HTTPS reverse proxy with automatic Let's Encrypt certificates.

## Prerequisites

Domain with DNS A record pointing to your server.

## Install Caddy

### Ubuntu/Debian:
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list

sudo apt update
sudo apt install caddy
```

### Fedora:
```bash
sudo dnf install 'dnf-command(copr)'
sudo dnf copr enable @caddy/caddy
sudo dnf install caddy
```

### openSUSE:
```bash
# Download binary directly
ARCH="amd64"  # or arm64
curl -sL "https://caddyserver.com/api/download?os=linux&arch=${ARCH}" -o /tmp/caddy
sudo install -m 755 /tmp/caddy /usr/local/bin/caddy
rm /tmp/caddy

# Create user
sudo groupadd --system caddy
sudo useradd --system --gid caddy --create-home \
  --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy
```

## Configure

1. **Copy Caddyfile from private-dots:**
   ```bash
   sudo mkdir -p /etc/caddy
   sudo cp ~/private-dots/caddy/Caddyfile /etc/caddy/Caddyfile
   sudo chown root:root /etc/caddy/Caddyfile
   sudo chmod 644 /etc/caddy/Caddyfile
   ```

2. **Example Caddyfile for Headscale:**
   ```
   mesh.your-domain.com {
       reverse_proxy localhost:8080

       log {
           output file /var/log/caddy/mesh.your-domain.com.log
       }
   }
   ```

3. **Validate config:**
   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   ```

## Setup Logging

```bash
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo chmod 750 /var/log/caddy
```

## Firewall

```bash
# Allow HTTP (for ACME challenge) and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now caddy
```

## Verify

1. **Check status:**
   ```bash
   sudo systemctl status caddy
   ```

2. **View logs:**
   ```bash
   sudo journalctl -u caddy -f
   ```

3. **Test HTTPS:**
   ```bash
   curl -I https://your-domain.com
   ```

4. **View access logs:**
   ```bash
   sudo tail -f /var/log/caddy/your-domain.com.log
   ```

## Reload After Changes

```bash
# Edit config
sudo nano /etc/caddy/Caddyfile

# Validate
sudo caddy validate --config /etc/caddy/Caddyfile

# Reload (zero-downtime)
sudo systemctl reload caddy
```

## Troubleshooting

- **Let's Encrypt fails:** Ensure DNS is configured and ports 80/443 are open
- **Connection refused:** Check backend service is running (e.g., `ss -tlnp | grep 8080`)
- **Logs:** `sudo journalctl -u caddy -n 100`

## Notes

- Caddy automatically obtains and renews Let's Encrypt certificates
- Certificates are stored in `/var/lib/caddy/.local/share/caddy/`
- Use `reverse_proxy` directive to proxy backend services
- Supports multiple domains in one Caddyfile

## Documentation

- https://caddyserver.com/docs/
- https://caddyserver.com/docs/caddyfile

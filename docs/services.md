# Services Documentation

This document covers all services used in the dotfiles infrastructure, including setup, configuration, security, and troubleshooting.

## Table of Contents

1. [Headscale VPN](#headscale-vpn)
2. [Syncthing](#syncthing)
3. [Service Users Pattern](#service-users-pattern)
4. [Systemd Hardening](#systemd-hardening)
5. [Security Best Practices](#security-best-practices)

---

## Headscale VPN

Headscale is an open-source, self-hosted implementation of the Tailscale control server.

### Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│  Laptop     │      │  Headscale   │      │  Desktop    │
│  (Client)   │◄────►│  VPS Server  │◄────►│  (Client)   │
└─────────────┘      └──────────────┘      └─────────────┘
                             │
                             ▼
                     ┌──────────────┐
                     │  Phone       │
                     │  (Client)    │
                     └──────────────┘
```

### Setup

**Prerequisites:**
- VPS or server with public IP
- Domain name (optional, for HTTPS)
- Firewall access (port 8080 for control server)

**Installation:**
```bash
cd ~/dotfiles
./scripts/setup-headscale.sh
```

**What the script does:**
1. Downloads and installs headscale binary
2. Creates `headscale` service user
3. Sets up directories: `/etc/headscale`, `/var/lib/headscale`, `/var/log/headscale`
4. Copies configuration from `dotfiles/headscale/config.yaml`
5. Creates systemd service with hardening
6. Configures firewall (ufw)
7. Initializes database
8. Creates default namespace

### Configuration

**Main config:** `/etc/headscale/config.yaml`

Key settings to customize:
```yaml
# Your public URL (replace with your domain)
server_url: https://vpn.yourdomain.com

# For production, enable HTTPS
listen_addr: 0.0.0.0:443

# DNS configuration
dns:
  magic_dns: true
  base_domain: vpn.local  # Must differ from server_url domain
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
```

After config changes:
```bash
sudo systemctl restart headscale
```

### Device Enrollment

**1. Create pre-auth key:**
```bash
sudo -u headscale headscale preauthkeys create \
  --expiration 24h \
  --namespace default
```

**2. On client device (Linux/Mac/Windows):**
```bash
# Install Tailscale client first
tailscale up \
  --login-server http://YOUR_SERVER:8080 \
  --authkey YOUR_PREAUTH_KEY
```

**3. Verify connection:**
```bash
# On server
sudo -u headscale headscale nodes list

# On client
tailscale status
```

### Access Control Lists (ACLs)

Create ACL policy file:
```bash
sudo -u headscale nano /etc/headscale/acls.yaml
```

Example ACL:
```yaml
acls:
  - action: accept
    src: ["*"]
    dst: ["*:*"]
```

Update config to use ACL:
```yaml
policy:
  mode: file
  path: /etc/headscale/acls.yaml
```

### Useful Commands

```bash
# List all nodes
sudo -u headscale headscale nodes list

# List namespaces
sudo -u headscale headscale namespaces list

# Create namespace
sudo -u headscale headscale namespaces create NAMESPACE

# Delete node
sudo -u headscale headscale nodes delete --identifier NODE_ID

# View routes
sudo -u headscale headscale routes list

# Service status
sudo systemctl status headscale
sudo journalctl -u headscale -f
```

### Troubleshooting

**Client can't connect:**
- Check server is running: `sudo systemctl status headscale`
- Verify firewall: `sudo ufw status`
- Check logs: `sudo journalctl -u headscale -n 100`
- Ensure server_url is accessible from client

**Database issues:**
```bash
# Check database
sudo -u headscale headscale db migrate

# Backup database
sudo -u headscale cp /var/lib/headscale/db.sqlite \
  /var/backups/headscale-db-$(date +%Y%m%d).sqlite
```

---

## Syncthing

Syncthing provides continuous file synchronization between devices.

### Architecture

**Gateway Mode (VPS):**
```
┌──────────┐     ┌─────────────┐     ┌──────────────┐
│ Laptop   │────►│  Gateway    │────►│ Google Drive │
│ Desktop  │     │  (Syncthing │     │  (rclone)    │
│ Phone    │     │  + rclone)  │     └──────────────┘
└──────────┘     └─────────────┘
```

**Personal Device Mode:**
```
┌──────────┐     ┌─────────────┐
│ Laptop   │◄───►│  Gateway    │
│ Desktop  │     │  Server     │
└──────────┘     └─────────────┘
```

### Setup

**Gateway Server:**
```bash
cd ~/dotfiles
./scripts/setup-sync.sh gateway
```

**Personal Devices:**
```bash
cd ~/dotfiles
./scripts/setup-sync.sh desktop  # or minimal, server
```

### Configuration

**Syncthing Web UI:**
- Local: http://localhost:8384
- Check service: `systemctl --user status syncthing`

**Adding devices:**
1. Get device ID: `syncthing --device-id`
2. In Web UI: Add Remote Device
3. Share folders with device
4. Accept connection on other device

### Gateway-Specific Setup

The gateway acts as a bridge to cloud storage:

**Rclone service user:** `rclone-sync`
- Home: `/var/lib/rclone-sync`
- Logs: `/var/log/rclone-sync`

**Sync script:** `~/bin/sync-to-cloud.sh`
- Runs every 15 minutes (cron)
- Syncs Syncthing folders to Google Drive
- Excludes `.stversions/`, `.stfolder/`, `.stignore`

**View sync logs:**
```bash
tail -f ~/.local/state/sync-to-cloud.log
```

**Manual sync:**
```bash
~/bin/sync-to-cloud.sh
```

### Folder Sharing

**Default synced folders** (based on profile):
- `~/code/personal` - All profiles
- `~/code/work` - Desktop, server, gateway
- `~/Documents` - All profiles
- `~/Photos` - Desktop, gateway

See `scripts/setup-folders.sh` for complete list.

### Troubleshooting

**Syncthing not starting:**
```bash
# Check service
systemctl --user status syncthing

# Restart service
systemctl --user restart syncthing

# Check logs
journalctl --user -u syncthing -n 50
```

**Devices not connecting:**
- Verify both devices have correct IDs
- Check firewall allows Syncthing (usually automatic with UPnP)
- Ensure devices are introduced (both added each other)
- Check Syncthing Web UI for connection errors

**Conflicts:**
- Syncthing creates `.sync-conflict` files
- Review and resolve manually
- Configure ignore patterns in `.stignore` if needed

---

## Service Users Pattern

### Why Service Users?

Running services as dedicated system users provides:
- **Isolation**: Limits damage if service is compromised
- **Least Privilege**: Service only accesses what it needs
- **Auditing**: Clear ownership of files and processes
- **Security**: Prevents privilege escalation

### Implementation

Service users are created with:
- System account (UID < 1000)
- No login shell (`/bin/false`)
- Dedicated home directory
- Minimal permissions

**Library function:**
```bash
create_service_user "service-name" "/var/lib/service-name"
```

**Example services:**
- `headscale` - VPN control server
- `rclone-sync` - Cloud sync daemon
- `syncthing` - File synchronization (runs as user)

### Directory Structure

**Standard layout for system services:**
```
/etc/SERVICE_NAME/          # Configuration files (640, owned by service)
/var/lib/SERVICE_NAME/      # Data and state (750, owned by service)
/var/log/SERVICE_NAME/      # Log files (750, owned by service)
/var/run/SERVICE_NAME/      # Runtime files like sockets (755, owned by service)
```

**Library function:**
```bash
setup_service_directories "service-name" \
  "/etc/service" \
  "/var/lib/service" \
  "/var/log/service"
```

---

## Systemd Hardening

### Security Features

Modern systemd services should include hardening directives:

**Filesystem Protection:**
```ini
ProtectSystem=strict          # Read-only /usr, /boot, /efi
ProtectHome=true             # No access to /home
ReadWritePaths=/var/lib/service  # Explicitly allow writes
PrivateTmp=true              # Private /tmp namespace
```

**Privilege Restrictions:**
```ini
NoNewPrivileges=true         # Prevent privilege escalation
PrivateDevices=true          # No access to physical devices
ProtectKernelModules=true    # Can't load kernel modules
ProtectKernelTunables=true   # Can't modify kernel params
ProtectControlGroups=true    # Can't modify cgroups
```

**Network Restrictions:**
```ini
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
# Only allow Unix sockets and IP networking
```

**Capability Restrictions:**
```ini
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
# Only allow binding to privileged ports if needed
```

**Process Restrictions:**
```ini
LimitNOFILE=65536           # Max open files
LimitNPROC=512              # Max processes
MemoryDenyWriteExecute=true # W^X enforcement
RestrictRealtime=true       # No realtime scheduling
```

### Example: Hardened Service

```ini
[Unit]
Description=My Secure Service
After=network-online.target

[Service]
Type=simple
User=myservice
Group=myservice

ExecStart=/usr/local/bin/myservice
Restart=always

# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/myservice /var/log/myservice
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

[Install]
WantedBy=multi-user.target
```

### Testing Hardening

**Analyze service security:**
```bash
systemd-analyze security SERVICE_NAME
```

**Check running service:**
```bash
systemctl show SERVICE_NAME | grep -E 'Protect|Private|Restrict'
```

---

## Security Best Practices

### Firewall Configuration

**Enable UFW:**
```bash
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**Allow necessary ports:**
```bash
# SSH
sudo ufw allow 22/tcp

# Headscale
sudo ufw allow 8080/tcp

# HTTPS (if using TLS)
sudo ufw allow 443/tcp

# List rules
sudo ufw status numbered
```

### File Permissions

**Configuration files:**
```bash
# Readable only by service user and root
sudo chown service-user:service-user /etc/service/config.yaml
sudo chmod 640 /etc/service/config.yaml
```

**Secret files:**
```bash
# Readable only by service user
sudo chmod 600 /var/lib/service/private.key
```

**Directories:**
```bash
# Service user and group can read/write/execute
sudo chmod 750 /var/lib/service
```

### Backup Strategy

**Use library functions:**
```bash
# Backup single file
backup_file "/etc/service/config.yaml" "/var/backups"

# Backup directory
backup_directory "/var/lib/service" "/var/backups"

# Clean old backups (keep 10 newest)
clean_old_backups "*.bak.*" 10 "/var/backups"
```

**Automate backups:**
```bash
# Create systemd timer for regular backups
# See lib/systemd.sh create_systemd_timer()
```

### Updates

**Headscale:**
```bash
# Check current version
headscale version

# Download new version
HEADSCALE_VERSION=0.26.2 ./scripts/setup-headscale.sh

# Restart service
sudo systemctl restart headscale
```

**Syncthing:**
```bash
# Update via package manager
sudo apt update && sudo apt upgrade syncthing

# Restart service
systemctl --user restart syncthing
```

### Monitoring

**Service status:**
```bash
# Check all services
systemctl --user list-units --type=service --state=running
sudo systemctl list-units --type=service --state=running

# Watch specific service
watch -n 1 systemctl status headscale
```

**Logs:**
```bash
# Follow service logs
sudo journalctl -u headscale -f

# Show recent errors
sudo journalctl -u headscale -p err -n 50

# Filter by time
sudo journalctl -u headscale --since "1 hour ago"
```

**Resource usage:**
```bash
# Check service resources
systemctl status headscale
ps aux | grep headscale

# Detailed resource info
systemd-cgtop
```

### Security Checklist

- [ ] All services run as dedicated service users
- [ ] Systemd hardening enabled (ProtectSystem, NoNewPrivileges, etc.)
- [ ] Firewall configured with minimal open ports
- [ ] Configuration files have restrictive permissions (640 or 600)
- [ ] Regular backups configured and tested
- [ ] Logs monitored for errors and anomalies
- [ ] Services kept up-to-date
- [ ] Unnecessary services disabled
- [ ] SSH key-based authentication (disable password auth)
- [ ] Fail2ban or similar intrusion prevention (optional)

---

## Quick Reference

### Common Commands

**Headscale:**
```bash
sudo -u headscale headscale nodes list
sudo -u headscale headscale preauthkeys create -e 24h --namespace default
sudo systemctl restart headscale
```

**Syncthing:**
```bash
systemctl --user status syncthing
syncthing --device-id
```

**Service Users:**
```bash
id headscale
sudo -u headscale ls -la /var/lib/headscale
```

**Firewall:**
```bash
sudo ufw status
sudo ufw allow PORT/PROTOCOL
```

**Logs:**
```bash
sudo journalctl -u SERVICE -f
journalctl --user -u SERVICE -f
```

### Useful Scripts

- `scripts/setup-headscale.sh` - Setup Headscale VPN
- `scripts/setup-sync-gateway.sh` - Setup gateway with Syncthing + rclone
- `scripts/setup-syncthing.sh` - Setup Syncthing on personal devices
- `scripts/sync-status.sh` - Check sync status (if exists)

### Library Functions

**Service users:** `lib/service-user.sh`
- `create_service_user USERNAME [HOMEDIR]`
- `setup_service_directories USERNAME DIR1 [DIR2...]`
- `set_service_file_permissions USERNAME FILEPATH [MODE]`

**Systemd:** `lib/systemd.sh`
- `enable_user_service SERVICE`
- `create_system_service SERVICE_NAME SERVICE_FILE`
- `wait_for_system_service SERVICE [MAX_WAIT]`

**Syncthing:** `lib/sync.sh`
- `get_syncthing_device_id`
- `setup_syncthing_systemd`
- `wait_for_syncthing_ready [MAX_WAIT]`

**Backup:** `lib/backup.sh`
- `backup_file FILE [BACKUP_DIR]`
- `backup_directory DIR [BACKUP_DIR]`
- `clean_old_backups PATTERN [KEEP_COUNT] [DIR]`

---

*Last updated: $(date +%Y-%m-%d)*

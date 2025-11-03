# Rclone + Syncthing Gateway Setup

Gateway server that bridges Syncthing (devices) ↔ Google Drive (cloud backup).

## Prerequisites

```bash
# openSUSE
sudo zypper in syncthing rclone

# Ubuntu
sudo apt install syncthing rclone
```

## Setup Syncthing

1. **Enable Syncthing:**
   ```bash
   systemctl --user enable --now syncthing
   ```

2. **Get device ID:**
   ```bash
   syncthing --device-id
   ```
   Share this with your personal devices.

3. **Configure via web GUI:**
   ```
   http://localhost:8384
   ```
   - Accept device connections from your laptops/desktops
   - Share folders with connected devices

## Setup Rclone

1. **Configure Google Drive remote:**
   ```bash
   rclone config
   ```

   Steps:
   - Choose `n` for new remote
   - Name it: `gdrive`
   - Choose `drive` for Google Drive
   - Leave `client_id` and `client_secret` blank
   - Choose `n` for advanced config
   - Choose `y` for auto config (OAuth browser flow)
   - Choose `n` for team drive
   - Confirm with `y`

2. **Test the connection:**
   ```bash
   rclone lsd gdrive:
   ```

## Create Sync Script

Create `~/bin/sync-to-cloud.sh`:

```bash
#!/bin/bash
# Sync Syncthing folders to Google Drive

LOG_FILE="$HOME/.local/state/sync-to-cloud.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Sync started: $(date) ===" >> "$LOG_FILE"

sync_folder() {
    local folder=$1
    local remote=$2

    if [ -d "$folder" ]; then
        echo "Syncing $folder..." >> "$LOG_FILE"
        rclone sync "$folder" "$remote" \
            --exclude ".stversions/**" \
            --exclude ".stfolder/**" \
            --exclude ".stignore" \
            --log-file="$LOG_FILE" \
            --log-level INFO
    fi
}

# Add your folders here
sync_folder "$HOME/code" "gdrive:code"
sync_folder "$HOME/Documents" "gdrive:Documents"
sync_folder "$HOME/Photos" "gdrive:Photos"

echo "=== Sync completed: $(date) ===" >> "$LOG_FILE"
```

Make it executable:
```bash
chmod +x ~/bin/sync-to-cloud.sh
```

## Setup Automatic Sync

Add to crontab (runs every 15 minutes):

```bash
crontab -e
```

Add:
```
*/15 * * * * $HOME/bin/sync-to-cloud.sh
```

## Monitor

```bash
# Test manual sync
~/bin/sync-to-cloud.sh

# Watch logs
tail -f ~/.local/state/sync-to-cloud.log

# Check Syncthing status
xdg-open http://localhost:8384
```

## Notes

- The gateway acts as a middleman: Devices → Syncthing → Rclone → Google Drive
- Syncthing metadata (`.stversions/`, `.stfolder/`) is excluded from cloud backup
- Adjust sync frequency in crontab as needed

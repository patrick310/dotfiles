# Syncthing Setup

Personal device file synchronization.

## Prerequisites

```bash
# openSUSE
sudo zypper in syncthing

# Ubuntu
sudo apt install syncthing
```

## Setup

1. **Enable the service:**
   ```bash
   systemctl --user enable --now syncthing
   ```

2. **Get your device ID:**
   ```bash
   syncthing --device-id
   ```
   Save this ID to share with your gateway server or other devices.

3. **Open the web GUI:**
   ```
   http://localhost:8384
   ```

4. **Add remote devices:**
   - Click "Add Remote Device" in bottom-right
   - Enter the other device's ID (e.g., gateway server)
   - The other device will need to accept your connection

5. **Share folders:**
   Common folders to sync:
   - `~/code` - Development projects
   - `~/Documents` - Documents
   - `~/Photos` - Photos (desktop only)
   - `~/Music` - Music library (desktop only)

## Check Status

```bash
# View web GUI
xdg-open http://localhost:8384

# Check service status
systemctl --user status syncthing

# View logs
journalctl --user -u syncthing -f
```

## Notes

- Syncthing creates `.stversions/` folders for file versioning
- Excluded files can be configured in `.stignore`
- Conflicts are handled automatically with versioning

#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-sync.sh
# This is safe to share publicly!

setup_rclone() {
    echo "Setting up rclone for cloud sync..."
    
    # Install rclone
    if ! command -v rclone &> /dev/null; then
        case "$OS" in
            ubuntu) sudo apt install rclone ;;
            fedora) sudo dnf install rclone ;;
            opensuse) sudo zypper install rclone ;;
        esac
    fi
    
    # Check if gdrive already configured
    if ! rclone listremotes | grep -q "gdrive:"; then
        echo "==================================="
        echo "Configure Google Drive with rclone:"
        echo "1. Choose 'n' for new remote"
        echo "2. Name it: gdrive"
        echo "3. Choose 'drive' for Google Drive"
        echo "4. Follow OAuth flow"
        echo "==================================="
        rclone config
    fi
    
    # Create mount point
    mkdir -p ~/Drive
    
    # Setup systemd service
    setup_gdrive_service
}

setup_gdrive_service() {
    # Create systemd user service (also public)
    mkdir -p ~/.config/systemd/user
    
    cat > ~/.config/systemd/user/gdrive.service << 'EOF'
[Unit]
Description=Google Drive mount
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: %h/Drive \
    --vfs-cache-mode writes \
    --dir-cache-time 48h \
    --poll-interval 30s
ExecStop=/bin/fusermount -u %h/Drive
Restart=on-failure

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable gdrive
    systemctl --user start gdrive
}

setup_sync_folders() {
    echo "Setting up folder sync structure..."
    
    # Wait for mount
    sleep 2
    
    # Create cloud structure
    mkdir -p ~/Drive/{Documents,Pictures,Books,Backups}
    
    # Link local folders to cloud
    for folder in Documents Pictures Books; do
        if [ -d ~/"$folder" ] && [ ! -L ~/"$folder" ]; then
            # Backup existing
            echo "Moving existing $folder to Drive..."
            rsync -av ~/"$folder"/ ~/Drive/"$folder"/
            rm -rf ~/"$folder"
        fi
        
        # Create symlink
        ln -sfn ~/Drive/"$folder" ~/"$folder"
        echo "  ✓ Linked ~/$folder → ~/Drive/$folder"
    done
}

# Main execution
setup_rclone
setup_sync_folders

echo "✅ Cloud sync setup complete!"
echo "📁 Your Documents, Pictures, and Books now sync to Google Drive"
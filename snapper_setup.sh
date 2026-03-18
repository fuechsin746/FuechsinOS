#!/bin/bash

# Configuration
SNAPSHOT_CONF="root"
ALLOW_GROUP="wheel"

echo "--- Initializing Snapper & rEFInd Snapshot Boot ---"

# 1. Install Snapper
sudo pacman -S --needed snapper

# 2. Configure Snapper for Root
# Handle existing .snapshots subvolume created in install script
sudo umount /.snapshots 2>/dev/null
sudo rm -rf /.snapshots
sudo snapper -c $SNAPSHOT_CONF create-config /
sudo rmdir /.snapshots
sudo mkdir /.snapshots
sudo mount -a

# 3. Permissions & Retention
sudo chown :$ALLOW_GROUP /.snapshots
sudo chmod 775 /.snapshots
sudo sed -i "s/ALLOW_GROUPS=\"\"/ALLOW_GROUPS=\"$ALLOW_GROUP\"/" /etc/snapper/configs/$SNAPSHOT_CONF

# Aggressive retention for 512GB NVMe
sudo sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="10"/' /etc/snapper/configs/$SNAPSHOT_CONF
sudo sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/$SNAPSHOT_CONF
sudo sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/$SNAPSHOT_CONF
sudo sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/$SNAPSHOT_CONF

# 4. Enable Timers
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# 5. Add rEFInd Snapshot Stanza
# Adds a fallback entry to boot into the first snapshot if things break
if ! grep -q "Boot from Snapshot" /boot/refind_linux.conf; then
cat <<EOF | sudo tee -a /boot/refind_linux.conf
"Boot from Snapshot (ID 1)"  "rw root=PARTLABEL=ARCH rootflags=subvol=@snapshots/1/snapshot initrd=\amd-ucode.img initrd=\initramfs-linux.img"
EOF
fi

# 6. Install snapper-rollback
# Uses XDG cache for temporary build files
GIT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/git"
mkdir -p "$GIT_DIR"
git clone https://github.com/jrabinow/snapper-rollback.git "$GIT_DIR/snapper-rollback"
sudo cp "$GIT_DIR/snapper-rollback/snapper-rollback.py" /usr/local/bin/snapper-rollback
sudo chmod +x /usr/local/bin/snapper-rollback

# Configure rollback tool
sudo cat <<CONF > /etc/snapper-rollback.conf
[subvolumes]
root = @
snapshots = @snapshots
CONF

echo "--- Snapper Setup Complete ---"

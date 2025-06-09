#!/bin/bash

CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

[ ! -b "$DISK_DEVICE" ] && { echo "Device not found: $DISK_DEVICE"; exit 1; }

CURRENT_DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

if ! mountpoint -q "$MOUNT_DIR"; then
    echo "SSHFS not mounted at $MOUNT_DIR"
    exit 1
fi

[ ! -d "$BACKUP_DIR" ] && { echo "Backup directory not found: $BACKUP_DIR"; exit 1; }

echo "Creating backup of $DISK_DEVICE..."
echo "Output: $BACKUP_DIR/$BACKUP_FILENAME"

sync

# Calculate 5% of device size
DEVICE_SIZE=$(blockdev --getsize64 "$DISK_DEVICE")
BLOCK_SIZE=33554432  # 32M in bytes
TOTAL_BLOCKS=$((DEVICE_SIZE / BLOCK_SIZE))
BLOCKS_5_PERCENT=$((TOTAL_BLOCKS * 5 / 100))

echo "Device size: $DEVICE_SIZE bytes"
echo "Total blocks (32M): $TOTAL_BLOCKS"
echo "Backing up first 5% ($BLOCKS_5_PERCENT blocks)..."

if dd if="$DISK_DEVICE" bs=32M count="$BLOCKS_5_PERCENT" 2>/dev/null | xz -T2 -3 > "$BACKUP_DIR/$BACKUP_FILENAME"; then
    echo "Success: $BACKUP_FILENAME (5% backup completed)"
else
    echo "Backup failed"
    exit 1
fi
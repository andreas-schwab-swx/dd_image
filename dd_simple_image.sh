#!/bin/bash

CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

[ ! -b "$DISK_DEVICE" ] && { echo "Device not found: $DISK_DEVICE"; exit 1; }

CURRENT_DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

echo "Creating and uploading backup of $DISK_DEVICE..."

sync

if dd if="$DISK_DEVICE" bs=32M 2>/dev/null | xz -T2 -3 | sftp "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/$BACKUP_FILENAME"; then
    echo "Success: $BACKUP_FILENAME"
else
    echo "Backup failed"
    exit 1
fi
#!/bin/bash

CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

[ ! -b "$DISK_DEVICE" ] && { echo "Device not found: $DISK_DEVICE"; exit 1; }

CURRENT_DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

mkdir -p "$MOUNT_DIR"
sshfs "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH" "$MOUNT_DIR" -o cache=yes,cache_timeout=1,reconnect,ServerAliveInterval=15

sync

DEVICE_SIZE=$(blockdev --getsize64 "$DISK_DEVICE")
TOTAL_BLOCKS=$((DEVICE_SIZE / 33554432))
BLOCKS_5_PERCENT=$((TOTAL_BLOCKS * 1 / 100))

dd if="$DISK_DEVICE" bs=32M count="$BLOCKS_5_PERCENT" status=progress | mbuffer -m 2G | xz -T2 -3 > "$MOUNT_DIR/$BACKUP_FILENAME"

fusermount -u "$MOUNT_DIR"

echo "Success: $BACKUP_FILENAME"
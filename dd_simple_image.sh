#!/bin/bash

CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

VG_FREE=$(vgs --noheadings --units g --nosuffix $LVM_VG | awk '{print int($7)}')
[ $VG_FREE -lt 2 ] && { echo "Not enough free space: ${VG_FREE}GB"; exit 1; }

SNAP_SIZE=$((VG_FREE - 1))
CURRENT_DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

echo "Creating snapshot ($SNAP_SIZE GB)..."
lvremove --force $LVM_VG/$SNAPSHOT_NAME 2>/dev/null || true
lvcreate -s -n $SNAPSHOT_NAME -L ${SNAP_SIZE}g $LVM_VG/$LVM_LV || exit 1

echo "Creating backup..."
TEMP_FILE="/dev/shm/backup_$$.img.xz"
LVM_VG_PATH=$(echo "$LVM_VG" | sed 's/-/--/g')
SNAPSHOT_PATH=$(echo "$SNAPSHOT_NAME" | sed 's/-/--/g')

dd if=/dev/$LVM_VG_PATH/$SNAPSHOT_PATH bs=32M 2>/dev/null | xz -T2 -3 > "$TEMP_FILE"

echo "Uploading..."
sftp_cmd=$(mktemp)
cat > "$sftp_cmd" << EOF
cd $REMOTE_PATH
put $TEMP_FILE $BACKUP_FILENAME
quit
EOF

sftp -b "$sftp_cmd" "$REMOTE_USER@$REMOTE_HOST" && echo "Success: $BACKUP_FILENAME" || echo "Upload failed"

rm -f "$sftp_cmd" "$TEMP_FILE"
lvremove --force $LVM_VG/$SNAPSHOT_NAME
#!/bin/bash

CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

CURRENT_DATE=$(date +"%Y-%m-%d-%H%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

echo "Creating backup (without snapshot)..."
TEMP_FILE="/dev/shm/backup_$$.img.xz"
LVM_VG_PATH=$(echo "$LVM_VG" | sed 's/-/--/g')
LVM_LV_PATH=$(echo "$LVM_LV" | sed 's/-/--/g')

sync

dd if=/dev/$LVM_VG_PATH/$LVM_LV_PATH bs=32M 2>/dev/null | xz -T2 -3 > "$TEMP_FILE" || { echo "Backup failed"; exit 1; }

echo "Uploading..."
sftp_cmd=$(mktemp)
cat > "$sftp_cmd" << EOF
cd $REMOTE_PATH
put $TEMP_FILE $BACKUP_FILENAME
quit
EOF

if sftp -b "$sftp_cmd" "$REMOTE_USER@$REMOTE_HOST"; then
    echo "Success: $BACKUP_FILENAME"
    rm -f "$sftp_cmd" "$TEMP_FILE"
else
    echo "Upload failed"
    rm -f "$sftp_cmd" "$TEMP_FILE"
    exit 1
fi
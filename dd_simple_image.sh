#!/bin/bash
# Simple LVM Snapshot Backup Script

# Load configuration
CONFIG_FILE="/etc/dd_image/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh and configure it"
    exit 1
fi
source "$CONFIG_FILE"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Calculate snapshot size (10% of LV size)
declare -i LV_SIZE=$(lvs $LVM_VG/$LVM_LV | awk 'FNR==2 {print $4}' | cut -d. -f1)
SNAP_SIZE=$((LV_SIZE*10/100))

# Find next available backup filename
CURRENT_DATE=$(date +"%Y-%m-%d")
find_remote_filename() {
    local current_date="$1"
    
    sftp_commands=$(mktemp)
    cat > "$sftp_commands" << EOF
cd $REMOTE_PATH
ls image-$current_date-*.img.xz
quit
EOF

    existing_files=$(sftp -b "$sftp_commands" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null \
                     | grep "image-$current_date-" | awk '{print $NF}' || true)
    rm -f "$sftp_commands"

    counter=1
    while [ $counter -le 99 ]; do
        counter_padded=$(printf "%02d" $counter)
        filename="image-$current_date-$counter_padded.img.xz"
        if ! echo "$existing_files" | grep -q "$filename"; then
            echo "$filename"
            return 0
        fi
        counter=$((counter + 1))
    done
    echo ""
    return 1
}

BACKUP_FILENAME=$(find_remote_filename "$CURRENT_DATE")
if [ -z "$BACKUP_FILENAME" ]; then
    echo "Error: Maximum number of backups per day (99) reached"
    exit 1
fi

echo "### Simple LVM Backup Script ###"
echo "Creating snapshot..."
echo "Name: $SNAPSHOT_NAME"
echo "Size: ${SNAP_SIZE}g"
echo "Partition size: ${LV_SIZE}g"

# Sync and create snapshot
sync
lvcreate -s -n $SNAPSHOT_NAME -L ${SNAP_SIZE}g $LVM_VG/$LVM_LV

echo "Creating backup: $BACKUP_FILENAME"

# Create temporary file for backup
TEMP_FILE="/dev/shm/backup_$$.img.xz"
export XZ_DEFAULTS="--memlimit=4GiB"

# Create backup from snapshot
if dd if=/dev/$LVM_VG/$SNAPSHOT_NAME bs=32M status=progress | xz -T2 -3 > "$TEMP_FILE"; then
    echo "Backup creation completed. Uploading..."
    
    # Upload via SFTP
    sftp_upload=$(mktemp)
    cat > "$sftp_upload" << EOF
cd $REMOTE_PATH
put $TEMP_FILE $BACKUP_FILENAME
quit
EOF
    
    if sftp -b "$sftp_upload" "$REMOTE_USER@$REMOTE_HOST"; then
        echo "Backup completed successfully: $BACKUP_FILENAME"
        rm -f "$sftp_upload" "$TEMP_FILE"
    else
        echo "Error: SFTP upload failed!"
        rm -f "$sftp_upload" "$TEMP_FILE"
        lvremove --force $LVM_VG/$SNAPSHOT_NAME
        exit 1
    fi
else
    echo "Error: Backup creation failed!"
    rm -f "$TEMP_FILE"
    lvremove --force $LVM_VG/$SNAPSHOT_NAME
    exit 1
fi

echo "Removing snapshot..."
lvremove --force $LVM_VG/$SNAPSHOT_NAME

echo "Backup completed: $BACKUP_FILENAME"

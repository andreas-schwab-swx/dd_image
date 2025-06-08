#!/bin/bash
# Full Disk Backup Script
# This script creates a complete image backup of the entire disk and cleans up old backups

# Exit on error
set -e

# Cleanup function for error handling
cleanup() {
    local exit_code=$?
    echo "Cleanup initiated (exit code: $exit_code)..."

    # Remove incomplete backup file if it exists
    if [ -n "$BACKUP_DIR" ] && [ -n "$BACKUP_FILENAME" ] && [ -f "$BACKUP_DIR/$BACKUP_FILENAME" ]; then
        echo "Removing incomplete backup file: $BACKUP_DIR/$BACKUP_FILENAME"
        rm -f "$BACKUP_DIR/$BACKUP_FILENAME"
    fi

    # Remove zero fill file if it exists
    if [ -f "/zero.fill" ]; then
        echo "Removing zero fill file: /zero.fill"
        rm -f /zero.fill
    fi

    # Unmount remote storage if mounted
    if [ -n "$MOUNT_DIR" ] && mount | grep -q "$MOUNT_DIR"; then
        echo "Unmounting remote storage: $MOUNT_DIR"
        sync
        sleep 2
        fusermount -u "$MOUNT_DIR" 2>/dev/null || umount "$MOUNT_DIR" 2>/dev/null || echo "Warning: Could not unmount $MOUNT_DIR"
    fi

    echo "Cleanup completed"
    exit $exit_code
}

# Set trap for cleanup on exit, interrupt, or termination
trap cleanup EXIT INT TERM

# Load configuration
CONFIG_FILE="$(dirname "$0")/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh and adjust the values."
    exit 1
fi

source "$CONFIG_FILE"

# Derived variables
CURRENT_DATE=$(date +"%Y-%m-%d")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"

mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/dd_image_$(date +%F).log"

{
    # Check and create local mount directory if needed
    if [ ! -d "$MOUNT_DIR" ]; then
        echo "Creating mount directory $MOUNT_DIR"
        mkdir -p "$MOUNT_DIR"
        chmod 0755 "$MOUNT_DIR"
        echo "Mount directory created"
    else
        echo "Mount directory already exists"
    fi

    # Check if remote filesystem is already mounted
    if ! mount | grep -q "$MOUNT_DIR"; then
        echo "Mounting remote storage..."
        sshfs $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH $MOUNT_DIR
        if [ $? -ne 0 ]; then
            echo "Failed to mount remote storage. Exiting."
            exit 1
        fi
        echo "Remote storage mounted successfully"
    else
        echo "Remote storage is already mounted"
    fi

    # Create backup directory if needed
    echo "Checking backup directory..."
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Creating backup directory $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        echo "Backup directory created"
    fi

    # Clear free space with zeros (optional)
    echo "Clearing free space with zeros (this may take a while)..."
    dd if=/dev/zero of=/zero.fill bs=32M status=progress || sudo rm -f /zero.fill
    echo "Free space cleared"

    # Sync filesystem to ensure data consistency
    echo "Syncing filesystems to ensure data consistency..."
    sync
    echo "Filesystems synced"

    # Backup the entire disk using dd and compress with gzip
    echo "Starting full disk backup of $DISK_DEVICE. This will take some time..."
    echo "Creating image and compressing on-the-fly..."
    export XZ_DEFAULTS="--memlimit=4GiB"
    dd conv=sparse if=$DISK_DEVICE bs=32M status=progress | xz -T2 -3 > "$BACKUP_DIR/$BACKUP_FILENAME" || { echo "Backup failed"; exit 1; }
    echo "Backup completed and saved to $BACKUP_DIR/$BACKUP_FILENAME"

    # Clean up old backups
    echo "Searching for backup files older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "image-*.img.xz" -type f -mtime +$RETENTION_DAYS -exec rm -fv {} \; || echo "No old backups to delete or error during deletion"
    echo "Old backups cleaned up"

    echo "Full disk backup process completed successfully!"
    echo "Backup saved as: $BACKUP_DIR/$BACKUP_FILENAME"
} >> "$LOGFILE" 2>&1

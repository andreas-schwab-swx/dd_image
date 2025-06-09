#!/bin/bash

# Lock file for preventing parallel execution
exec 200>/var/lock/dd_image.lock
flock -n 200 || { echo "Backup already running"; exit 1; }

# Load configuration file
CONFIG_FILE="/etc/dd_image/config.sh"
[ ! -f "$CONFIG_FILE" ] && { echo "Config file not found: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

# Generate backup filename
CURRENT_DATE=$(date +"%Y-%m-%d-%H-%M")
BACKUP_FILENAME="image-$CURRENT_DATE.img.xz"  # Generate backup filename
LOGFILE="$LOG_DIR/image-$CURRENT_DATE.log"    # Generate log filename

# Create log directory and remove old logs
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -name "image-*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
exec > >(tee "$LOGFILE") 2>&1

# Check if script is running as root
[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

# Email notification function
email() {
    local subject="$1"  # Subject of the email with SUCCESS OR FAILED
    local status="$2"   # SUCCESS or ERROR

    if [ "$EMAIL_NOTIFICATIONS" = "true" ] && [ -n "$EMAIL_RECIPIENT" ]; then
        echo "Sending email notification to $EMAIL_RECIPIENT..."
        {
            echo "$subject"
            echo "============================="
            echo ""
            echo "Status: $status"
            echo "Time: $(date)"
            echo "Host: $(hostname)"
            echo ""
            echo "Backup file: $BACKUP_FILENAME"
            echo ""
            echo "Details:"
            echo "- Device: $DISK_DEVICE"
            echo "- Backup size: 5% of disk"
            echo "- Remote location: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
            echo ""
            echo "Log file: $LOGFILE"
        } | mail -r "$EMAIL_FROM" -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null || \
            echo "Warning: Failed to send email notification"
    fi
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        echo "Error: $BACKUP_FILENAME"

        rm -f "$MOUNT_DIR/$BACKUP_FILENAME" 2>/dev/null
        email "DD Image Backup FAILED" "ERROR"
    else
        echo "Success: $BACKUP_FILENAME"

        email "DD Image Backup SUCCESS" "SUCCESS"
    fi
    fusermount -u "$MOUNT_DIR" 2>/dev/null || true
}

# Check if disk device exists
[ ! -b "$DISK_DEVICE" ] && { echo "Device not found: $DISK_DEVICE"; exit 1; }

# Mount remote directory
mkdir -p "$MOUNT_DIR"
sshfs "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH" "$MOUNT_DIR" -o cache=yes,cache_timeout=1,reconnect,ServerAliveInterval=15

# Set trap for cleanup on exit, interrupt, or termination
trap 'cleanup' EXIT

# Delete backups older than retention days
find "$MOUNT_DIR" -name "image-*.img.xz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# Sync filesystem to ensure data consistency
sync

# Calculate size of 5% of the disk device
DEVICE_SIZE=$(blockdev --getsize64 "$DISK_DEVICE")
TOTAL_BLOCKS=$((DEVICE_SIZE / 33554432))
BLOCKS_5_PERCENT=$((TOTAL_BLOCKS * 1 / 100))

# Perform backup using dd, mbuffer, and xz
dd if="$DISK_DEVICE" bs=32M count="$BLOCKS_5_PERCENT" status=progress | mbuffer -m 1G -q | xz -T3 -3 > "$MOUNT_DIR/$BACKUP_FILENAME"

# Cleanup
cleanup

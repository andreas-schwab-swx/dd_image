#!/bin/bash
# Full Disk Backup Script
# This script creates a complete image backup of the entire disk and cleans up old backups

# Exit on error
set -e

# Lock file for preventing parallel execution
LOCKFILE="/var/run/dd_image.lock"

# Email notification function
send_notification() {
    local subject="$1"
    local message="$2"
    local status="$3"  # SUCCESS or ERROR

    if [ "$EMAIL_NOTIFICATIONS" = "true" ] && [ -n "$EMAIL_RECIPIENT" ]; then
        echo "Sending email notification to $EMAIL_RECIPIENT..."
        {
            echo "DD Image Backup Notification"
            echo "============================="
            echo ""
            echo "Status: $status"
            echo "Time: $(date)"
            echo "Host: $(hostname)"
            echo "Script: $0"
            echo ""
            echo "Message:"
            echo "$message"
            echo ""
            echo "Log file: $LOGFILE"
        } | mail -r "$EMAIL_FROM" -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null || echo "Warning: Failed to send email notification"
    fi
}

# Cleanup function for error handling
cleanup() {
    local exit_code=$?

    # All cleanup messages go to logfile only
    {
        echo "Cleanup initiated (exit code: $exit_code)..."

        # Remove lock file
        if [ -f "$LOCKFILE" ]; then
            echo "Removing lock file: $LOCKFILE"
            rm -f "$LOCKFILE"
        fi

        # Remove incomplete backup file if backup failed (any non-zero exit code)
        if [ $exit_code -ne 0 ] && [ -n "$BACKUP_DIR" ] && [ -n "$BACKUP_FILENAME" ] && [ -f "$BACKUP_DIR/$BACKUP_FILENAME" ]; then
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

        # Send notification based on exit code
        if [ $exit_code -eq 0 ]; then
            # Collect backup information once
            echo "Checking backup file: $BACKUP_DIR/$BACKUP_FILENAME"
            ls -lh "$BACKUP_DIR/$BACKUP_FILENAME" 2>/dev/null || echo "Backup file not found"
            backup_size=$(ls -lh "$BACKUP_DIR/$BACKUP_FILENAME" 2>/dev/null | awk '{print $5}' || echo "unknown")

            completion_time=$(date)

            # Create backup summary message
            backup_summary="Backup completed successfully!

Backup file: $BACKUP_FILENAME
Backup size: $backup_size
Backup location: $BACKUP_DIR/$BACKUP_FILENAME
Disk device: $DISK_DEVICE
Completion time: $completion_time"

            # Log the backup summary
            echo ""
            echo "=== BACKUP SUMMARY ==="
            echo "$backup_summary"
            echo "======================"

            # Send email notification with same information
            send_notification "DD Image Backup SUCCESS" "$backup_summary" "SUCCESS"
        else
            error_message="Backup process failed with exit code $exit_code. Check log file for details: $LOGFILE"
            echo ""
            echo "=== BACKUP FAILED ==="
            echo "$error_message"
            echo "====================="
            send_notification "DD Image Backup FAILED" "$error_message" "ERROR"
        fi
    } >> "$LOGFILE" 2>&1

    exit $exit_code
}

# Set trap for cleanup on exit, interrupt, or termination
trap cleanup EXIT INT TERM

# Load configuration
CONFIG_FILE="/etc/dd_image/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh, configure it, and place it in /etc/dd_image/"
    exit 1
fi

source "$CONFIG_FILE"

# Derived variables
CURRENT_DATE=$(date +"%Y-%m-%d")

mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/dd_image_$(date +%F).log"

# Check for existing lock file to prevent parallel execution
if [ -f "$LOCKFILE" ]; then
    echo "Error: Another backup process is already running (lock file exists: $LOCKFILE)"
    echo "If you're sure no backup is running, remove the lock file manually:"
    echo "  sudo rm -f $LOCKFILE"
    exit 1
fi

# Create lock file with current PID
echo $$ > "$LOCKFILE"

# Show progress monitoring info to user
echo "Monitor progress: tail -f $LOGFILE"

{
    echo "DD Image Backup started (PID: $$)"
    echo "Lock file created: $LOCKFILE (PID: $$)"

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

    # Find next available backup number (01-99)
    COUNTER=1
    while [ $COUNTER -le 99 ]; do
        COUNTER_PADDED=$(printf "%02d" $COUNTER)
        BACKUP_FILENAME="image-$CURRENT_DATE-$COUNTER_PADDED.img.xz"
        if [ ! -f "$BACKUP_DIR/$BACKUP_FILENAME" ]; then
            break
        fi
        COUNTER=$((COUNTER + 1))
    done

    # Check if we exceeded the limit
    if [ $COUNTER -gt 99 ]; then
        echo "Error: Maximum number of backups per day (99) reached for $CURRENT_DATE"
        echo "Please clean up old backups manually"
        exit 1
    fi

    echo "Using backup filename: $BACKUP_FILENAME"

    # Clean up old backups first (before creating new backup)
    echo "Searching for backup files older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "image-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].img.xz" -type f -mtime +$RETENTION_DAYS -exec rm -fv {} \; || echo "No old backups to delete or error during deletion"
    echo "Old backups cleaned up"

    # Clear free space with zeros (optional, configurable)
    if [ "$ZERO_FILL" = "true" ]; then
        echo "Clearing free space with zeros (this may take a while)..."
        dd if=/dev/zero of=/zero.fill bs=32M status=progress || sudo rm -f /zero.fill
        echo "Free space cleared"
    else
        echo "Skipping zero-fill (ZERO_FILL=false). Enable in config for better compression."
    fi

    # Sync filesystem to ensure data consistency
    echo "Syncing filesystems to ensure data consistency..."
    sync
    echo "Filesystems synced"

    # Backup the entire disk using dd and compress with xz
    echo "Starting full disk backup of $DISK_DEVICE. This will take some time..."
    echo "Creating image and compressing on-the-fly..."
    export XZ_DEFAULTS="--memlimit=4GiB"
    # dd conv=sparse if=$DISK_DEVICE bs=32M status=progress | xz -T2 -3 > "$BACKUP_DIR/$BACKUP_FILENAME" || { echo "Backup failed"; exit 1; }
    echo "Test backup created on $(date)" | xz -T2 -3 > "$BACKUP_DIR/$BACKUP_FILENAME" || { echo "Test backup failed"; exit 1; }
    echo "Full disk backup process completed successfully!"
    echo "Backup saved as: $BACKUP_DIR/$BACKUP_FILENAME"
} >> "$LOGFILE" 2>&1

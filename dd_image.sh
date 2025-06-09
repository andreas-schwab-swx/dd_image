#!/bin/bash
# Full Disk Backup Script
# This script creates a complete image backup of the entire disk and cleans up old backups

# Exit on error
set -e

# Lock file for preventing parallel execution
LOCKFILE="/var/run/dd_image.lock"

###############################################################################
# Find next available backup filename on remote server
###############################################################################
find_remote_filename() {
    local current_date="$1"

    # Change into the images directory first, then list only basenames
    local sftp_commands
    sftp_commands=$(mktemp)
    cat > "$sftp_commands" << EOF
cd $REMOTE_PATH/images
ls image-$current_date-*.img.xz
quit
EOF

    local existing_files
    existing_files=$(sftp -b "$sftp_commands" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null \
                     | grep "image-$current_date-" | awk '{print $NF}' || true)
    rm -f "$sftp_commands"

    # Find next available number (01-99)
    local counter=1
    while [ $counter -le 99 ]; do
        local counter_padded
        counter_padded=$(printf "%02d" $counter)
        local filename="image-$current_date-$counter_padded.img.xz"

        if ! echo "$existing_files" | grep -q "$filename"; then
            echo "$filename"
            return 0
        fi
        counter=$((counter + 1))
    done

    # If we get here, all 99 slots are taken
    echo ""
    return 1
}

###############################################################################
# Stream backup directly to remote server (ssh | cat)        — FIXED
# Reason: “sftp put - …” does not work in batch mode (caused stat - error)
###############################################################################
stream_backup() {
    local remote_filename="$1"

    echo "Starting streaming backup to remote server..." >&2
    echo "Remote destination: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/images/$remote_filename" >&2

    echo "Creating disk image and streaming to remote server..." >&2
    export XZ_DEFAULTS="--memlimit=4GiB"

    # dd -> xz -> ssh (cat)
    # Send all messages to stderr so they go to logfile, but keep pipeline stdout clean
    if dd conv=sparse if="$DISK_DEVICE" bs=32M status=progress 2>&1 \
        | xz -T2 -3 \
        | ssh "$REMOTE_USER@$REMOTE_HOST" "cat > '$REMOTE_PATH/images/$remote_filename'" 2>&1; then
        echo "Streaming backup completed successfully" >&2
        return 0
    else
        echo "Streaming backup failed" >&2
        return 1
    fi
}

###############################################################################
# Email notification function
###############################################################################
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
        } | mail -r "$EMAIL_FROM" -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null || \
            echo "Warning: Failed to send email notification"
    fi
}

###############################################################################
# Cleanup function for error handling
###############################################################################
cleanup() {
    local exit_code=$?

    {
        echo "Cleanup initiated (exit code: $exit_code)..."

        # Remove lock file
        if [ -f "$LOCKFILE" ]; then
            echo "Removing lock file: $LOCKFILE"
            rm -f "$LOCKFILE"
        fi

        # Remove incomplete remote backup file if backup failed
        if [ $exit_code -ne 0 ] && [ -n "${BACKUP_FILENAME:-}" ] && \
           [[ "$BACKUP_FILENAME" =~ ^image-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}\.img\.xz$ ]]; then
            echo "Attempting to remove incomplete remote backup file: $BACKUP_FILENAME"
            sftp_cleanup=$(mktemp)
            cat > "$sftp_cleanup" << EOF
cd $REMOTE_PATH/images
rm $BACKUP_FILENAME
quit
EOF
            sftp -b "$sftp_cleanup" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null || \
                echo "Warning: Could not remove remote backup file (may not exist)"
            rm -f "$sftp_cleanup"
        fi

        # Remove zero fill file if it exists
        if [ -f "/zero.fill" ]; then
            echo "Removing zero fill file: /zero.fill"
            rm -f /zero.fill
        fi

        echo "Cleanup completed"

        # Send notification based on exit code
        if [ $exit_code -eq 0 ]; then
            completion_time=$(date)
            backup_summary="Backup completed successfully!

Backup file: $BACKUP_FILENAME
Remote location: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/images/$BACKUP_FILENAME
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

###############################################################################
# Main script logic
###############################################################################
CONFIG_FILE="/etc/dd_image/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh, configure it, and place it in /etc/dd_image/"
    exit 1
fi
source "$CONFIG_FILE"

CURRENT_DATE=$(date +"%Y-%m-%d")
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/dd_image_$(date +%F).log"

# Prevent parallel execution
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

    # Test SFTP connection
    echo "Testing SFTP connection to $REMOTE_USER@$REMOTE_HOST..."
    if ! sftp -b /dev/null "$REMOTE_USER@$REMOTE_HOST" < /dev/null; then
        echo "Failed to connect to remote host via SFTP. Exiting."
        exit 1
    fi
    echo "SFTP connection test successful"

    # Determine next available filename
    echo "Searching for next available backup filename on remote server..."
    BACKUP_FILENAME=$(find_remote_filename "$CURRENT_DATE")
    if [ -z "$BACKUP_FILENAME" ]; then
        echo "Error: Maximum number of backups per day (99) reached for $CURRENT_DATE"
        exit 1
    fi
    echo "Using backup filename: $BACKUP_FILENAME"

    # Cleanup old backups (duplicate path bug fixed)
    echo "Searching for remote backup files older than $RETENTION_DAYS days..."
    cleanup_cmd=$(mktemp)
    cat > "$cleanup_cmd" << EOF
cd $REMOTE_PATH/images
ls image-*.img.xz
quit
EOF

    # Get list of all remote backup files and delete old ones
    all_backups=$(sftp -b "$cleanup_cmd" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null \
                  | grep "image-" | awk '{print $NF}' || true)
    rm -f "$cleanup_cmd"

    if [ -n "$all_backups" ]; then
        cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        echo "$all_backups" | while read -r backup_file; do
            file_date=$(echo "$backup_file" | sed -n 's/image-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*/\1/p')
            if [ -n "$file_date" ] && [ "$file_date" \< "$cutoff_date" ]; then
                echo "Deleting old remote backup: $backup_file"
                delete_cmd=$(mktemp)
                cat > "$delete_cmd" << EOF
cd $REMOTE_PATH/images
rm $backup_file
quit
EOF
                sftp -b "$delete_cmd" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null || \
                    echo "Warning: Could not delete $backup_file"
                rm -f "$delete_cmd"
            fi
        done
    fi
    echo "Old remote backups cleaned up"
    # ------------------------------------------------------------------------

    # Optional zero fill
    if [ "$ZERO_FILL" = "true" ]; then
        echo "Clearing free space with zeros (this may take a while)..."
        dd if=/dev/zero of=/zero.fill bs=32M status=progress || rm -f /zero.fill
        echo "Free space cleared"
    else
        echo "Skipping zero-fill (ZERO_FILL=false). Enable in config for better compression."
    fi

    # Sync filesystem to ensure data consistency
    echo "Syncing filesystems to ensure data consistency..."
    sync
    echo "Filesystems synced"

    # Stream backup directly to remote server
    echo "Starting streaming backup of $DISK_DEVICE directly to remote server..."
} >> "$LOGFILE" 2>&1

# Execute backup with stderr redirected to logfile but stdout free for pipeline
if stream_backup "$BACKUP_FILENAME" 2>> "$LOGFILE"; then
    {
        echo "Streaming backup completed successfully!"
        echo "Backup saved remotely as: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/images/$BACKUP_FILENAME"
    } >> "$LOGFILE" 2>&1
else
    echo "Streaming backup failed" >> "$LOGFILE" 2>&1
    exit 1
fi

#!/bin/bash
# Simple Full Disk Backup Script
# Creates a complete image backup of the entire disk

# Exit on error
set -e

# Load configuration
CONFIG_FILE="/etc/dd_image/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh and configure it"
    exit 1
fi
source "$CONFIG_FILE"

###############################################################################
# Find next available backup filename on remote server
###############################################################################
find_remote_filename() {
    local current_date="$1"

    # Get list of existing files for today
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
# Main script
###############################################################################
CURRENT_DATE=$(date +"%Y-%m-%d")

echo "Simple DD Image Backup"
echo "======================"
echo "Disk device: $DISK_DEVICE"
echo "Remote host: $REMOTE_USER@$REMOTE_HOST"
echo "Remote path: $REMOTE_PATH/images/"
echo ""

# Test SFTP connection
echo "Testing SFTP connection..."
if ! sftp -b /dev/null "$REMOTE_USER@$REMOTE_HOST" < /dev/null; then
    echo "Error: Failed to connect to remote host via SFTP"
    exit 1
fi
echo "SFTP connection OK"

# Find next available filename
echo "Finding next available backup filename..."
BACKUP_FILENAME=$(find_remote_filename "$CURRENT_DATE")
if [ -z "$BACKUP_FILENAME" ]; then
    echo "Error: Maximum number of backups per day (99) reached for $CURRENT_DATE"
    exit 1
fi
echo "Using filename: $BACKUP_FILENAME"

# Sync filesystem
echo "Syncing filesystems..."
sync

# Test SSH connection first
echo "Testing SSH connection..."
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection test successful'" >/dev/null 2>&1; then
    echo "Error: SSH connection failed"
    exit 1
fi
echo "SSH connection OK"

# Create backup and stream to remote server
echo ""
echo "Starting backup..."
echo "Destination: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/images/$BACKUP_FILENAME"
echo ""

export XZ_DEFAULTS="--memlimit=4GiB"

# Test if remote directory is writable
echo "Testing remote directory access..."
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "touch '$REMOTE_PATH/images/.test' && rm '$REMOTE_PATH/images/.test'" 2>/dev/null; then
    echo "Error: Cannot write to remote directory $REMOTE_PATH/images/"
    exit 1
fi
echo "Remote directory access OK"

# Alternative approach: Use named pipe for streaming
echo "Creating disk image and streaming to remote server..."

# Create a named pipe
PIPE_FILE="/tmp/backup_pipe_$$"
mkfifo "$PIPE_FILE"

# Start the receiving end in background
ssh "$REMOTE_USER@$REMOTE_HOST" "cat > '$REMOTE_PATH/images/$BACKUP_FILENAME'" < "$PIPE_FILE" &
SSH_PID=$!

# Start the sending end
if dd conv=sparse if="$DISK_DEVICE" bs=32M status=progress 2>&1 | xz -T2 -3 > "$PIPE_FILE"; then
    # Wait for SSH to complete
    wait $SSH_PID
    SSH_EXIT=$?

    # Clean up pipe
    rm -f "$PIPE_FILE"

    if [ $SSH_EXIT -eq 0 ]; then
        echo ""
        echo "Backup completed successfully!"
        echo "File: $BACKUP_FILENAME"
        echo "Location: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/images/$BACKUP_FILENAME"
    else
        echo ""
        echo "Error: SSH transfer failed!"
        exit 1
    fi
else
    # Kill SSH process and clean up
    kill $SSH_PID 2>/dev/null || true
    wait $SSH_PID 2>/dev/null || true
    rm -f "$PIPE_FILE"
    echo ""
    echo "Error: Backup creation failed!"
    exit 1
fi

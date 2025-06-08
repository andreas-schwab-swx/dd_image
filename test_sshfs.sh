#!/bin/bash
# Simple SSHFS Test Script

set -e

# Load configuration
source /etc/dd_image/config.sh

echo "Testing SSHFS connection..."
echo "Remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

# Create mount directory
mkdir -p "$MOUNT_DIR"

# Mount SSHFS
echo "Mounting SSHFS..."
sshfs "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH" "$MOUNT_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# List existing files in backup directory
echo "Existing files in $BACKUP_DIR:"
ls -la "$BACKUP_DIR"

# Create test file
TEST_FILE="sshfs-test-$(date +%s).txt"
echo "SSHFS test - $(date)" > "$BACKUP_DIR/$TEST_FILE"
echo "Test file created: $TEST_FILE"

# List again existing files in backup directory
echo "Updated files in $BACKUP_DIR:"
ls -la "$BACKUP_DIR"

# Cleanup
rm -f "$BACKUP_DIR/$TEST_FILE"
fusermount -u "$MOUNT_DIR"

echo "SSHFS test completed successfully"

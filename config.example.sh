#!/bin/bash
# DD Image Backup Configuration Example
# Copy this file to config.sh and adjust the values for your setup

# Remote storage configuration
REMOTE_USER="your-username"
REMOTE_HOST="your-storage-host.com"
REMOTE_PATH="/path/to/your/backup/directory"

# Local mount configuration
MOUNT_DIR="/root/your-storage-mount"
BACKUP_DIR="$MOUNT_DIR/images"

# Backup configuration
DISK_DEVICE="/dev/vda"  # The entire disk to backup (adjust as needed: /dev/sda, /dev/nvme0n1, etc.)
RETENTION_DAYS=60       # Number of days to keep backups

# Logging configuration
LOG_DIR="/var/log/dd_image"

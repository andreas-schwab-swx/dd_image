#!/bin/bash
# DD Image Backup Configuration Example
# Copy this file to config.sh and adjust the values for your setup

# Remote storage configuration (SFTP)
REMOTE_USER="your-username"
REMOTE_HOST="your-storage-host.com"
REMOTE_PATH="/path/to/your/backup/directory"

# Remote backup directory URL (for reference)
# Example: http://your-username.your-storagebox.de/your-path/images

# Backup configuration
DISK_DEVICE="/dev/vda"  # The entire disk to backup (adjust as needed: /dev/sda, /dev/nvme0n1, etc.)
RETENTION_DAYS=60       # Number of days to keep backups
ZERO_FILL=false         # Set to true to clear free space with zeros (improves compression but takes much longer)

# LVM Snapshot configuration
USE_LVM_SNAPSHOT=false                         # Set to true to use LVM snapshots for consistent backups
LVM_VG="your-volume-group"                     # Volume Group name (e.g., ubuntu-vg, centos, etc.)
LVM_LV="your-logical-volume"                   # Logical Volume name (e.g., ubuntu-lv, root, etc.)
SNAPSHOT_SIZE="5G"                             # Snapshot size (should be enough for changes during backup)
SNAPSHOT_NAME="root_snap"                      # Name for the snapshot
FREEZE_FILESYSTEM=true                         # Set to true to freeze filesystem before snapshot

# Logging configuration
LOG_DIR="/var/log/dd_image"

# Email notification configuration
EMAIL_NOTIFICATIONS=true             # Set to false to disable email notifications
EMAIL_FROM="backup@example.com"      # Sender email address
EMAIL_RECIPIENT="admin@example.com"  # Email address for notifications

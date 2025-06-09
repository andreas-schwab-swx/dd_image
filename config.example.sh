#!/bin/bash
# DD Image Backup Configuration Example
# Copy this file to config.sh and adjust the values for your setup

# Remote storage configuration (SFTP)
REMOTE_USER="your-username"
REMOTE_HOST="your-storage-host.com"
REMOTE_PATH="/path/to/your/backup/directory"

# Backup configuration
DISK_DEVICE="/dev/vda"  # The entire disk to backup (adjust as needed: /dev/sda, /dev/nvme0n1, etc.)
RETENTION_DAYS=60       # Number of days to keep backups
ZERO_FILL=false         # Set to true to clear free space with zeros (improves compression but takes much longer)

# Logging configuration
LOG_DIR="/var/log/dd_image"

# Email notification configuration
EMAIL_NOTIFICATIONS=true             # Set to false to disable email notifications
EMAIL_FROM="backup@example.com"      # Sender email address
EMAIL_RECIPIENT="admin@example.com"  # Email address for notifications

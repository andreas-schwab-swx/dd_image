#!/bin/bash
# DD Image Backup Configuration Example
# Copy this file to config.sh and adjust the values for your setup.

# Local mount directory (where the remote backup is mounted via sshfs)
MOUNT_DIR="/root/your-storagebox.de/images"  # Example: /root/u123456.your-storagebox.de/images

# Remote storage configuration (SSHFS)
REMOTE_USER="your-username"                   # SSH/SFTP username
REMOTE_HOST="your-storage-host.com"           # Hostname or IP of the storage server
REMOTE_PATH="/path/to/your/backup/directory"  # Target directory on the remote server

# Backup configuration
DISK_DEVICE="/dev/vda"        # Block device to backup (e.g. /dev/sda, /dev/nvme0n1)
RETENTION_DAYS=60              # Number of days to keep backups
ZERO_FILL=false                # true: overwrite free space with zeros (improves compression, takes longer)
SCRIPT_INTERVAL_DAYS=7         # Interval (in days) how often the script typically runs (for zero-fill logic)

# Logging configuration
LOG_DIR="/var/log/dd_image"   # Directory for log files

# Email notification
EMAIL_NOTIFICATIONS=true             # true: enable email notifications
EMAIL_RECIPIENT="backup@example.com"  # Recipient address for notifications
EMAIL_FROM="admin@example.com"         # Sender address for notifications

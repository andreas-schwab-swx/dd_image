# DD Image Backup Script

A comprehensive shell script for creating full disk image backups with automatic compression and remote storage via SSHFS.

## Features

- **Full Disk Backup**: Creates complete disk images using `dd`
- **On-the-fly Compression**: Uses XZ compression to minimize storage space
- **Remote Storage**: Automatically mounts and stores backups on remote storage via SSHFS
- **Automatic Cleanup**: Removes old backups based on retention policy
- **Progress Monitoring**: Shows backup progress with detailed logging
- **Data Consistency**: Ensures filesystem sync before backup
- **Free Space Optimization**: Zeros out free space for better compression
- **Email Notifications**: Sends success/failure notifications via local mail server
- **Lock File Protection**: Prevents concurrent backup processes

## Prerequisites

- Linux system with root access
- `sshfs` package installed
- `xz` compression utility
- SSH key-based authentication configured for remote storage
- Sufficient disk space on remote storage
- Local mail server configured (for email notifications)

### Installing Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install sshfs xz-utils

# CentOS/RHEL/Fedora
sudo yum install fuse-sshfs xz
# or
sudo dnf install fuse-sshfs xz
```

## Configuration

The script uses an external configuration file to keep sensitive data out of the repository.

1. **Copy the example configuration:**
   ```bash
   cp config.example.sh config.sh
   ```

2. **Edit `config.sh` with your settings:**
   ```bash
   # Remote storage configuration
   REMOTE_USER="your-username"
   REMOTE_HOST="your-storage-host.com"
   REMOTE_PATH="/path/to/your/backup/directory"

   # Local mount configuration
   MOUNT_DIR="/root/your-storage-mount"
   BACKUP_DIR="$MOUNT_DIR/images"

   # Backup configuration
   DISK_DEVICE="/dev/vda"  # Adjust as needed: /dev/sda, /dev/nvme0n1, etc.
   RETENTION_DAYS=60       # Days to keep old backups

   # Logging configuration
   LOG_DIR="/var/log/dd_image"

   # Email notification configuration
   EMAIL_NOTIFICATIONS=true          # Set to false to disable email notifications
   EMAIL_RECIPIENT="admin@example.com"  # Email address for notifications
   ```

**Note:** The `config.sh` file is gitignored to protect your sensitive configuration data.

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/andreas-schwab-swx/dd_image.sh.git
   cd dd_image.sh
   ```

2. **Copy and configure the settings:**
   ```bash
   cp config.example.sh config.sh
   nano config.sh  # Edit with your settings
   ```

3. **Make the script executable:**
   ```bash
   chmod +x dd_image.sh
   ```

4. **Configure SSH key authentication:**
   ```bash
   ssh-keygen -t rsa -b 4096
   ssh-copy-id user@remote-host.com
   ```

5. **Test SSHFS connection:**
   ```bash
   mkdir -p /tmp/test-mount
   sshfs user@remote-host.com:/path /tmp/test-mount
   fusermount -u /tmp/test-mount
   ```

6. **Configure local mail server (optional):**
   ```bash
   # Install mail utilities (Ubuntu/Debian)
   sudo apt-get install mailutils

   # Test email functionality
   echo "Test message" | mail -s "Test Subject" your-email@example.com
   ```

## Usage

### Manual Execution
```bash
sudo ./dd_image.sh
```

### Automated Execution (Cron)
Add to root's crontab for weekly backups:
```bash
sudo crontab -e
# Add this line for weekly backups at 2 AM on Sundays
0 2 * * 0 /path/to/dd_image.sh
```

## File Structure

```
dd_image.sh/
├── .github/
│   └── workflows/
│       └── deploy.yml   # GitHub Actions deployment workflow
├── .gitignore           # Git ignore file (protects config.sh)
├── LICENSE              # GPLv3 License
├── README.md            # This file
├── config.example.sh    # Example configuration file
├── config.sh            # Your configuration (gitignored)
└── dd_image.sh          # Main backup script
```

## Logging

Logs are automatically created in `/var/log/dd_image/` with the format:
```
/var/log/dd_image/dd_image_YYYY-MM-DD.log
```

## Important Notes

- **Backup Process**: The script creates a complete disk image, which can take several hours
- **Disk Space**: Ensure remote storage has sufficient space (at least 2x the disk size)
- **System Load**: The backup process is I/O intensive and may affect system performance
- **Free Space Clearing**: The zero-fill operation can take significant time but improves compression
- **Root Access**: Script must be run as root to access disk devices

## Security Considerations

- Use SSH key authentication instead of passwords
- Restrict SSH access to backup user only
- Consider encrypting backups for sensitive data
- Regularly test backup integrity
- Monitor backup logs for errors

## Troubleshooting

### Common Issues

**SSHFS Mount Fails:**
```bash
# Check SSH connectivity
ssh user@remote-host.com

# Verify SSHFS is installed
which sshfs
```

**Insufficient Permissions:**
```bash
# Ensure script runs as root
sudo ./dd_image.sh
```

**Disk Space Issues:**
```bash
# Check available space on remote storage
df -h /mount/point
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Automated Deployment

The repository includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) for automatic deployment to your server.

### Setup GitHub Actions Deployment

1. **Configure GitHub Secrets** in your repository settings:
   - `HOST`: Your server's IP address or hostname
   - `USERNAME`: SSH username for your server
   - `SSH_KEY`: Private SSH key for authentication

2. **Deployment Process:**
   - Triggers on every push to `main` branch
   - Clones/updates the repository on your server
   - Copies script to `/usr/local/sbin/dd_image.sh`
   - Sets proper permissions and ownership

3. **Server Requirements:**
   - SSH access configured
   - Git installed
   - Sudo access for the deployment user

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Performance Tips

- **Block size**: Script uses optimized `bs=32M` for systems with 8GB+ RAM
- **XZ compression**: Uses `-T2` threads (optimal for 4 vCPU systems)
- **Compression level**: Uses `-3` for faster compression with slightly larger files
- **Alternative**: Use `-5` or `-6` for better compression but slower speed
- **Memory limit**: XZ limited to 4GiB to prevent system overload

## Support

If you encounter issues or have questions:
- Check the troubleshooting section above
- Review log files in `/var/log/dd_image/`
- Open an issue on GitHub

---

**Disclaimer**: Always test backups in a non-production environment first. Verify backup integrity before relying on them for disaster recovery.

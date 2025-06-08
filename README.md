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

## Prerequisites

- Linux system with root access
- `sshfs` package installed
- `xz` compression utility
- SSH key-based authentication configured for remote storage
- Sufficient disk space on remote storage

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

Edit the variables at the top of `dd_image.sh` to match your setup:

```bash
REMOTE_USER="your-username"           # Remote storage username
REMOTE_HOST="your-storage-host.com"   # Remote storage hostname
REMOTE_PATH="/path/to/backup/dir"     # Remote directory path
DISK_DEVICE="/dev/vda"                # Disk device to backup
RETENTION_DAYS=60                     # Days to keep old backups
```

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/dd_image_backup.git
   cd dd_image_backup
   ```

2. **Make the script executable:**
   ```bash
   chmod +x dd_image.sh
   ```

3. **Configure SSH key authentication:**
   ```bash
   ssh-keygen -t rsa -b 4096
   ssh-copy-id user@remote-host.com
   ```

4. **Test SSHFS connection:**
   ```bash
   mkdir -p /tmp/test-mount
   sshfs user@remote-host.com:/path /tmp/test-mount
   fusermount -u /tmp/test-mount
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
dd_image_backup/
├── dd_image.sh          # Main backup script
├── README.md            # This file
└── LICENSE              # GPLv3 License
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

## Performance Tips

- Adjust `bs=4M` block size based on your system (try 8M or 16M)
- Increase XZ threads (`-T`) based on available CPU cores
- Use faster compression level (`-3` instead of `-5`) for speed
- Consider using `pigz` for parallel gzip compression as alternative

## Support

If you encounter issues or have questions:
- Check the troubleshooting section above
- Review log files in `/var/log/dd_image/`
- Open an issue on GitHub

---

**Disclaimer**: Always test backups in a non-production environment first. Verify backup integrity before relying on them for disaster recovery.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Performance Tips

- Adjust `bs=4M` block size based on your system (try 8M or 16M)
- Increase XZ threads (`-T`) based on available CPU cores
- Use faster compression level (`-3` instead of `-5`) for speed
- Consider using `pigz` for parallel gzip compression as alternative

## Support

If you encounter issues or have questions:
- Check the troubleshooting section above
- Review log files in `/var/log/dd_image/`
- Open an issue on GitHub

---

**Disclaimer**: Always test backups in a non-production environment first. Verify backup integrity before relying on them for disaster recovery.

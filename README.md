# DD Image Backup Script

This repository contains scripts for creating compressed disk image backups and managing them efficiently.

## Features

- Create compressed disk images
- Mount remote backup directories via SSHFS
- Automatic backup retention management (deletes old backups)
- Optional zero-filling of free space for better compression
- Logging of all operations
- Email notifications on backup success or failure
- Locking to prevent parallel execution
- Easy configuration via `config.sh`
- Optional: Use `dd_image_compare.sh` to compare different compression algorithms

## Prerequisites & Dependencies

Make sure the following tools are installed on your system:

- `bash` (for script execution)
- `dd` (for disk imaging)
- `mbuffer` (for efficient buffering)
- `sshfs` (for mounting remote directories)
- Compression tools: `zstd` (required), and optionally `pigz`, `bzip2`, `gzip`, `lz4`, `xz` (for full functionality)
- `mail` (for email notifications, optional)
- `flock` (for locking)
- `ls`, `awk`, `find`, `tee`, `sync`, `fusermount` (standard Unix tools)

## Main Script: `dd_image.sh`

`dd_image.sh` is the main backup script. It performs the following tasks:

- Creates a compressed image of a specified block device using multiple compression methods
- Mounts a remote backup directory via SSHFS
- Manages backup retention
- Optionally zero-fills free space at the beginning of each month (configurable)
- Logs all operations and can send email notifications
- Prevents parallel execution using a lock file
- Configuration is handled via `config.sh` (see `config.example.sh` for all options and documentation)

### Usage

1. Copy `config.example.sh` to `config.sh` and adjust all parameters to your environment.
2. Ensure all required tools (see above) are installed.
3. Run the script as root:
   ```sh
   sudo ./dd_image.sh
   ```
4. (Optional) Set up a cron job to run the script automatically (e.g., weekly or monthly).

## Comparison Script: `dd_image_compare.sh`

The script `dd_image_compare.sh` is used to compare different compression algorithms and helps you find the best trade-off between backup time and disk space usage.

## Configuration

All configuration is done in `config.sh`. See `config.example.sh` for detailed parameter explanations and example values.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

**Disclaimer**: Always test backups in a non-production environment first. Verify backup integrity before relying on them for disaster recovery.

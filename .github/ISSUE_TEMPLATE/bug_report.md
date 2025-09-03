---
name: Bug report
about: Create a report to help us improve.
title: ''
labels: 'bug'
assignees: ''

---

**Describe the bug**  
A clear and concise description of what the bug is.

**To Reproduce**  
Steps to reproduce the behavior:
1. Run `./dd_image.sh ...`
2. …
3. …

**Expected behavior**  
A clear and concise description of what you expected to happen.

**Logs / Error output**  
If applicable, paste relevant log excerpts or error messages here (please redact secrets).

**Environment (please complete the following information):**
- OS / Distro: [e.g. Ubuntu 24.04, Debian 12]
- Kernel: [e.g. `uname -r`]
- Script version / commit: [e.g. `git rev-parse --short HEAD`]
- Shell: [e.g. bash 5.2]
- Tools:
  - zstd: (`zstd --version`)
  - mbuffer: (`mbuffer -V`)
  - sshfs/fuse: (`sshfs -V`, `fusermount --version`)
- Backup source: [e.g. `/dev/sda`, LVM LV, ZFS zvol]
- Backup target: [local path, SSHFS mount, remote storage box]

**Screenshots / Diagrams (optional)**  
If applicable, add screenshots of error messages or diagrams showing your setup.

**Additional context**  
Add any other context about the problem here (network conditions, storage capacity, cron/systemd usage, etc.).

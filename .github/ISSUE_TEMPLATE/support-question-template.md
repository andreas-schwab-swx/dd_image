---
name: Support question template
about: Ask a question about using dd_image.
title: ''
labels: 'question'
assignees: ''

---

**Your question**  
Describe your question in detail.  
Ex: "How can I run dd_image with systemd timers instead of cron?"

**What you have tried**  
List the steps, commands, or configurations you already tested.  
Ex: "I tried adding a cronjob with `dd_image.sh` but logs are not created …"

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

**Relevant snippets (please redact secrets)**  
Paste short excerpts of configs (e.g. from `config.sh`) or log output that help understand your issue.

**Additional context**  
Add any other context that may help (network latency, storage capacity, cron/systemd setup, etc.).

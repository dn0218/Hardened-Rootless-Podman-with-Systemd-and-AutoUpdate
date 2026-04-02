# Hardened Rootless Podman with Quadlet & Auto-Ops

A production-grade implementation of rootless containers on RHEL 9, utilizing Systemd Quadlets for lifecycle management and automated image updates.

## 🌟 Core Features
- **Rootless Execution**: Container runs under a non-privileged `sysadmin` user, providing a strong security boundary.
- **Systemd Quadlet**: Modern "Declarative" container management (The RHEL 9.2+ standard).
- **Auto-Ops**: Automated image tracking and updates via Systemd timers.
- **Immutable Infrastructure**: Using the `--new` logic to ensure fresh container state on every restart.

## 🚀 Quick Start
1. **Prepare User**:
```bash
[danny@rhel ~]$ sudo useradd -m -s /bin/bash sysadmin
[danny@rhel ~]$ cat /etc/subuid
danny:100000:65536
sysadmin:165536:65536
[danny@rhel ~]$ sudo loginctl enable-linger sysadmin
```
In Rootless mode, exit from SSH might cause container stops. Enable linger feature to prevent this.

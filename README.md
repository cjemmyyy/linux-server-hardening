# Linux Server Hardening Script

A bash script that automates baseline security hardening on a fresh Ubuntu/Debian server.
Instead of manually configuring each setting, this script runs through all critical hardening
steps in one command — and logs every action with a timestamp.

---

## Why I Built This

A default Ubuntu server install is not production-ready. Root login is enabled, SSH accepts
passwords, there is no firewall, and nothing is monitoring for brute force attacks. This script
fixes all of that automatically, the same way a sysadmin would before deploying any real server.

---

## What It Does

| Phase | What Happens |
|-------|-------------|
| **Phase 1** | Root check, logging setup, system info display |
| **Phase 2** | System update, package installation (ufw, fail2ban, unattended-upgrades) |
| **Phase 3** | SSH hardening — disables root login, password auth, limits attempts to 3 |
| **Phase 4** | Firewall (UFW) — blocks all incoming except SSH, HTTP, HTTPS |
| **Phase 5** | Fail2Ban — bans IPs after 3 failed SSH attempts; enables auto security updates |
| **Phase 6** | Final report — prints summary and saves full audit log |

---

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04 (or Debian-based distro)
- Must be run as root or with `sudo`
- Internet connection (for package installation)

---

## How to Run

```bash
# Clone the repo
git clone https://github.com/cjemmyyy/linux-server-hardening.git
cd linux-server-hardening

# Make the script executable
chmod +x harden.sh

# Run as root
sudo bash harden.sh
```

---

## Sample Output

```
============================================
  Linux Server Hardening Script — Starting
============================================

[OK] Root check passed. Script started.
[OK] Logs will be saved to: /var/log/hardening_report.log

System info:
  Hostname : prod-server-01
  OS       : Ubuntu 22.04.3 LTS
  Uptime   : up 2 minutes
  Date     : Wed May 20 14:28:00 UTC 2026

============================================
  Phase 2 — System Update & Package Installation
============================================
[OK] Package list updated successfully.
[OK] Packages upgraded successfully.
[SKIP] ufw is already installed.
[OK] fail2ban installed successfully.
[SKIP] unattended-upgrades is already installed.
[DONE] Phase 2 complete — system is up to date.

============================================
  Phase 3 — SSH Hardening
============================================
[OK] Backup saved to: /etc/ssh/sshd_config.bak.2026-05-20
[OK] Root login disabled.
[OK] Password authentication disabled.
[OK] Empty passwords disabled.
[OK] MaxAuthTries set to 3.
[OK] SSH config test passed.
[OK] SSH service restarted successfully.
[DONE] Phase 3 complete — SSH is hardened.

============================================
  Phase 4 — Firewall Configuration (UFW)
============================================
[OK] Default policies set — deny incoming, allow outgoing.
[OK] SSH allowed.
[OK] HTTP (80) and HTTPS (443) allowed.
[OK] Firewall enabled successfully.
[DONE] Phase 4 complete — Firewall is active.

============================================
  Phase 5 — Fail2Ban & Automatic Security Updates
============================================
[OK] Fail2Ban jail.local created.
[OK] Fail2Ban service is running.
[OK] Automatic security updates configured.
[OK] Unattended upgrades service is running.
[DONE] Phase 5 complete — Fail2Ban active, auto updates enabled.

============================================
         HARDENING SUMMARY REPORT
============================================

  Hostname  : prod-server-01
  Date      : Wed May 20 14:28:54 UTC 2026
  Log file  : /var/log/hardening_report.log

  --- Changes Made ---

  SSH Configuration:
    Root login          : disabled
    Password auth       : disabled
    Empty passwords     : disabled
    Max auth tries      : 3

  Firewall (UFW):
    Status              : active
    Allowed ports       : 22 (SSH), 80 (HTTP), 443 (HTTPS)

  Services:
    SSH                 : active
    Fail2Ban            : active
    Auto updates        : active

  --- Post Hardening Reminders ---

  !  Make sure your SSH key is added before logging out
  !  Test SSH access in a new terminal before closing this session
  !  Review the full log at: /var/log/hardening_report.log

============================================
   Server hardening complete. Stay secure.
============================================
```

---

## SSH Settings Applied

| Setting | Value | Why |
|--------|-------|-----|
| `PermitRootLogin` | `no` | Root should never log in directly via SSH |
| `PasswordAuthentication` | `no` | Forces SSH key auth — passwords are brute-forceable |
| `PermitEmptyPasswords` | `no` | Blocks accounts with no password set |
| `MaxAuthTries` | `3` | Limits login attempts before disconnecting |

---

## Firewall Rules (UFW)

| Port | Protocol | Action | Purpose |
|------|----------|--------|---------|
| 22 | TCP | ALLOW | SSH access |
| 80 | TCP | ALLOW | HTTP web traffic |
| 443 | TCP | ALLOW | HTTPS web traffic |
| All others | ANY | DENY | Default deny everything else |

---

## Fail2Ban Configuration

| Setting | Value | Meaning |
|--------|-------|---------|
| `maxretry` | `3` | Ban after 3 failed login attempts |
| `findtime` | `600` | Within a 10 minute window |
| `bantime` | `3600` | Ban lasts 1 hour |

---

## Project Structure

```
linux-server-hardening/
├── harden.sh            # Main hardening script
├── README.md            # This file
├── sample-report.log    # Example log output

```

---

## Important Notes

- **Always set up SSH keys before running this script on a real server.**
  Password authentication is disabled — if you have no SSH key you will lose access.
- **Always test SSH access in a separate terminal** before closing your current session.
- This script is idempotent — running it multiple times will not break anything.
  Installed packages are skipped, backups are not overwritten, and services are restarted cleanly.
- The full audit log is saved to `/var/log/hardening_report.log`.

---

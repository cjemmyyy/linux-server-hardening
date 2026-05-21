
#!/bin/bash
# =======================================================================
# Linux Server Hardening Script
# Author: cjemmyyy
# Description: Automates baseline security hardening on fresh Ubuntu server
# =======================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'


LOG_FILE="/var/log/hardening_report.log"

log() {
    local MESSAGE="$1"
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d  %H:%M:%S')
    echo -e "$MESSAGE"
    echo "[$TIMESTAMP] $MESSAGE" >> "$LOG_FILE"
}

banner() {
    echo ""
    echo -e "${CYAN}===================================================${NC}"
    echo -e "${CYAN}	$1${NC}"
    echo -e "${CYAN}===================================================${NC}"
    echo ""
}

# ROOT CHECK
if  [[ $EUID -ne 0 ]]; then
     echo -e "${RED}[ERROR] This script must be run as root.${NC}"
     echo -e "${YELLOW}[TIP]  Try: sudo bash harden.sh${NC}"
     exit 1
fi

# ENTRY POINT
banner "Linux Server Hardening Script - Starting"
log "${GREEN}[OK] Root check passed. Script started. ${NC}"
log "${GREEN}[OK] Logs will be saved to: $LOG_FILE${NC}"

echo ""
echo -e "${YELLOW}System info:${NC}"
echo "  Hostname : $(hostname)"
echo "  OS	 : $(lsb_release -d | cut -f2)"
echo "  Uptime   : $(uptime -p)"
echo "  Date	 : $(date)"
echo ""

log "[INFO] Hostname: $(hostname)"
log "[INFO] OS: $(lsb_release -d | cut -f2)"


# PHASE 2

banner "Phase 2 - System Update & Package Installation"

log "${GREEN} Updating package list....${NC}"
apt update -y >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] Package list updated successfully.${NC}"
else
    log "${RED}[ERROR] Failed to update package list. Check your internet connection.${NC}"
    exit 1
fi

log "${GREEN} Upgrading installed packages...${NC}"
apt upgrade -y >> "$LOG_FILE" 2>&1

if  [[ $? -eq 0 ]]; then
     log "${GREEN}[OK] Packages upgraded succesfully.${NC}"
else
     log "${RED}[ERROR] Package upgrade failed.${NC}"
     exit 1
fi

log "${GREEN} Installing required tools...${NC}"

PACKAGES=("ufw" "fail2ban" "unattended-upgrades")

for PACKAGE in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $PACKAGE"; then
        log "${YELLOW}[SKIP] $PACKAGE is already installed.${NC}"
    else
        apt install -y "$PACKAGE" >> "$LOG_FILE" 2>&1
        if [[ $? -eq 0 ]]; then
	    log "${GREEN}[OK] $PACKAGE installed successfully.${NC}"
        else
	    log "${RED}[ERROR} Failed to install $PACKAGE.${NC}"
            exit 1
        fi
    fi
done

log "${GREEN}[DONE] Phase 2 complete - system is up to date.${NC}"



# PHASE 3

banner "Phase 3 - SSH Hardening"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backing up original config
log "${GREEN} Backing up SSH config...${NC}"
BACKUP_FILE="$SSHD_CONFIG.bak.$(date +%F)"

if [[ -f "$BACKUP_FILE" ]]; then
    log "${YELLOW}[SKIP] Backup already exists: $BACKUP_FILE${NC}"
else
    cp "$SSHD_CONFIG" "$BACKUP_FILE"
    log "${GREEN}[OK] Backup saved to: $BACKUP_FILE${NC}"
fi

# Disabling root login
log "${GREEN} Disabling root login...${NC}"
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
log "${GREEN}[OK] Root login disabled.${NC}"

# Disabling password authentication
log "${GREEN} Disabling password authentication...${NC}"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
log "${GREEN}[OK] Password authentication disabled.${NC}"

# Disabling empty passwords
log "${GREEN} Disabling empty passwords...${NC}"
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
log "${GREEN}[OK] Empty passwords disabled.${NC}"

# Limit max auth attempts
log "${GREEN} Setting max authentication attempts to 3...${NC}"
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
log "${GREEN}[OK] MaxAuthTries set to 3.${NC}"

# Verify changes before restarting
log "${GREEN} Verifying SSH config changes...${NC}"
echo ""
echo -e "${CYAN}--- Current SSH Settings ---${NC}"
grep -E "^PermitRootLogin|^PasswordAuthentication|^PermitEmptyPassword|^MaxAuthTries" "$SSHD_CONFIG"
echo ""

# Test config is valid before restarting
sshd -t >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] SSH config test passed.${NC}"
else
    log "${RED}[ERROR] SSH config has errors. Restoring backup...${NC}"
    cp "BACKUP_FILE" "$SSHD_CONFIG"
    log "${YELLOW}[OK] Original SSH config restored.${NC}"
    exit 1
fi

# Restart SSH
log "${GREEN} Restarting SSH service...${NC}"
systemctl restart sshd

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] SSH service restarted successfully.${NC}"
else
    log "${RED}[ERROR] SSH failed to restart.${NC}"
    exit 1
fi

log "${GREEN}[DONE] Phase 3 complete - SSH is hardened.${NC}"



# PHASE 4 - FIREWALL (UFW)

banner "Phase 4 - Firewall Configuration (UFW)"

# Set default policies
log "${GREEN} Setting default firewall policies...${NC}"
ufw default deny incoming >> "$LOG_FILE" 2>&1
ufw default allow outgoing >> "$LOG_FILE" 2>&1
log "${GREEN}[OK] Default policies set - deny incoming, allow outgoing.${NC}"

# allow ssh
log "${GREEN} Allowing SSH...${NC}"
ufw allow ssh >> "$LOG_FILE" 2>&1
log "${GREEN}[OK] SSH allowed.${NC}"

# allow HTTP and HTTPS
log "${GREEN} Allowing HTTP and HTTPS...${NC}"
ufw allow 80/tcp >> "$LOG_FILE" 2>&1
ufw allow 443/tcp >> "$LOG_FILE" 2>&1
log "${GREEN}[OK] HTTP (80) and HTTPS (443) allowed.${NC}"

# enable UFW
log "${GREEN} Enabling firewall...${NC}"
ufw --force enable >> "$LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] Firewall enabled successfully.${NC}"
else
    log "${RED}[ERROR] Failed to enable firewall.${NC}"
    exit 1
fi

# verify rules
log "${GREEN} Verifying firewall rules...${NC}"
echo ""
echo -e "${CYAN}--- Active Firewall Rules ---${NC}"
ufw status verbose
echo ""

log "${GREEN}[DONE] Phase 4 complete - Firewall is active.${NC}"



# PHASE 5 - FAIL2BAN & AUTO UPDATES
banner "Phase 5 - Fail2Ban & Automatic Security Updates"

# create jail.local config
log "${GREEN} Configuring Fail2Ban for SSH protection...${NC}"

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime   = 3600
findtime  = 600
maxretry  = 3

[sshd]
enabled   = true
port      = ssh
logpath   = %(sshd_log)s
backend   = %(sshd_backend)s
EOF

log "${GREEN}[OK] Fail2Ban jail.local created.${NC}"

# Enable and restart Fail2Ban
log "${GREEN} Enabling Fail2Ban service...${NC}"
systemctl enable fail2ban >> "$LOG_FILE" 2>&1
systemctl restart fail2ban >> "LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] Fail2Ban service is running.${NC}"
else
    log "${RED}[ERROR] Fail2Ban failed to start.${NC}"
    exit 1
fi

# Verify Fail2Ban is watching SSH
log "${GREEN} Verifying Fail2Ban SSH jail...${NC}"
echo ""
echo -e "${CYAN}--- Fail2Ban SSH Status ---${NC}"
sleep 3
fail2ban-client status sshd
echo ""

# auto updates- Configuring unattended upgrades
log "${GREEN} Configuring automatic security updates...${NC}"

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log "${GREEN}[OK] Automatic security updates configured.${NC}"

# enable the service
systemctl enable unattended-upgrades >> "$LOG_FILE" 2>&1
systemctl restart unattended-upgrades >> "LOG_FILE" 2>&1

if [[ $? -eq 0 ]]; then
    log "${GREEN}[OK] Unattended upgrades service is running.${NC}"
else
    log "${RED}[ERROR] Unattended upgrades failed to start.${NC}"
    exit 1
fi

log "${GREEN}[DONE] Phase 5 complete - Fail2Ban active, auto updates enabled.${NC}"



# Phase 6 - Final report & Cleanup
banner "Phase 6 - Final Report"

# service status checks
SSH_STATUS=$(systemctl is-active sshd)
UFW_STATUS=$(ufw status | grep -w "Status" | awk '{print $2}')
FAIL2BAN_STATUS=$(systemctl is-active fail2ban)
UPGRADES_STATUS=$(systemctl is-active unattended-upgrades)

# Print summary
echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}	HARDENING SUMMARY REPORT		${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e "  Hostname  : $(hostname)"
echo -e "  Date	     : $(date)"
echo ""
echo -e "${CYAN} --- Changes Made ---${NC}"
echo ""
echo -e "  SSH Configuration:"
echo -e "    Root login		: ${GREEN}disabled${NC}"
echo -e "    Password auth	: ${GREEN}disabled${NC}"
echo -e "    Empty passwords    : ${GREEN}disabled${NC}"
echo -e "    Max auth tries	: ${GREEN}3${NC}"
echo ""
echo -e "  Firewall (UFW):"
echo -e "    Status		: ${GREEN}$UFW_STATUS${NC}"
echo -e "    Allowed ports	: ${GREEN}22 (SSH), 80 (HTTP), 443 (HTTPS)${NC}"
echo ""
echo -e "  Services:"
echo -e "    SSH		: ${GREEN}$SSH_STATUS${NC}"
echo -e "    Fail2Ban		: ${GREEN}$FAIL2BAN_STATUS${NC}"
echo -e "    Auto updates	: ${GREEN}$UPGRADES_STATUS${NC}"
echo ""
echo -e "${CYAN}  --- Post Hardening Reminders ---${NC}"
echo ""
echo -e "  ${YELLOW}!  Make sure your SSH key is added before logging out${NC}"
echo -e "  ${YELLOW}!  Test SSH access in a new terminal before closing this session${NC}"
echo -e "  ${YELLOW}!  Review the full log at: $LOG_FILE${NC}"
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   Server hardening complete. Stay secure.  ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Save summary to log

log "[REPORT] Hardening completed on $(hostname) at $(date)"
log "[REPORT] SSH hardened — root login disabled, keys only, max 3 attempts"
log "[REPORT] UFW active — ports 22, 80, 443 open"
log "[REPORT] Fail2Ban active — bans after 3 failed SSH attempts"
log "[REPORT] Unattended upgrades enabled"
log "${GREEN}[DONE] All phases complete.${NC}"

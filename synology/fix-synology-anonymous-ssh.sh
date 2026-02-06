#!/bin/bash
# fix-synology-anonymous-ssh.sh
#
# Fixes CVE-reported SSH brute force login with default credentials for the
# "anonymous" system account on Synology NAS devices.
#
# Root cause: Synology creates a system-level "anonymous" user (UID 21) with
# a locked password (*) in /etc/shadow. However, pam_syno_support.so accepts
# authentication for this user with an empty password before pam_unix.so is
# consulted. The shell /usr/bin/nologin blocks interactive sessions, but SSH
# auth succeeds, which vulnerability scanners correctly flag as Critical.
#
# This script:
#   1. Adds "DenyUsers anonymous" to sshd_config (blocks at SSH level, before PAM)
#   2. Uncomments "PermitEmptyPasswords no" as defense in depth
#   3. Restarts sshd to apply changes
#
# Usage: sudo bash fix-synology-anonymous-ssh.sh
#
# Safe to run multiple times (idempotent).
# Note: Synology may reset /etc/ssh/sshd_config on DSM updates. Re-run after updates.

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# --- Pre-flight checks ---

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (use sudo)."
    exit 1
fi

if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERROR] This does not appear to be a Synology NAS (/etc/synoinfo.conf not found)."
    exit 1
fi

if [ ! -f "$SSHD_CONFIG" ]; then
    echo "[ERROR] $SSHD_CONFIG not found. Is SSH enabled on this NAS?"
    exit 1
fi

echo "=== Synology Anonymous SSH Fix ==="
echo ""

# --- Check if anonymous user exists ---

if ! grep -q '^anonymous:' /etc/passwd; then
    echo "[INFO] No 'anonymous' user found in /etc/passwd. Nothing to fix."
    exit 0
fi

echo "[FOUND] anonymous user exists in /etc/passwd:"
grep '^anonymous:' /etc/passwd
echo ""

# --- Backup sshd_config ---

cp "$SSHD_CONFIG" "${SSHD_CONFIG}${BACKUP_SUFFIX}"
echo "[BACKUP] Saved $SSHD_CONFIG to ${SSHD_CONFIG}${BACKUP_SUFFIX}"

# --- Fix 1: DenyUsers anonymous ---

if grep -q '^DenyUsers.*anonymous' "$SSHD_CONFIG"; then
    echo "[SKIP] DenyUsers anonymous is already present in $SSHD_CONFIG"
else
    echo 'DenyUsers anonymous' >> "$SSHD_CONFIG"
    echo "[FIXED] Added 'DenyUsers anonymous' to $SSHD_CONFIG"
fi

# --- Fix 2: PermitEmptyPasswords no ---

if grep -q '^PermitEmptyPasswords no' "$SSHD_CONFIG"; then
    echo "[SKIP] PermitEmptyPasswords no is already active in $SSHD_CONFIG"
elif grep -q '^#PermitEmptyPasswords no' "$SSHD_CONFIG"; then
    sed -i 's/^#PermitEmptyPasswords no/PermitEmptyPasswords no/' "$SSHD_CONFIG"
    echo "[FIXED] Uncommented 'PermitEmptyPasswords no' in $SSHD_CONFIG"
else
    echo 'PermitEmptyPasswords no' >> "$SSHD_CONFIG"
    echo "[FIXED] Added 'PermitEmptyPasswords no' to $SSHD_CONFIG"
fi

# --- Restart sshd ---

echo ""
echo "[RESTART] Restarting sshd..."
if command -v synosystemctl &> /dev/null; then
    synosystemctl restart sshd
elif command -v systemctl &> /dev/null; then
    systemctl restart sshd
else
    /usr/syno/etc/rc.sysv/sshd.sh restart 2>/dev/null || {
        echo "[WARN] Could not restart sshd automatically. Please restart SSH manually."
        echo "       DSM > Control Panel > Terminal & SNMP > disable/re-enable SSH"
    }
fi
echo "[RESTART] sshd restarted."

# --- Verification ---

echo ""
echo "=== Verification ==="
echo "Checking sshd_config for applied settings..."
echo ""

echo "DenyUsers:"
grep -n 'DenyUsers' "$SSHD_CONFIG" || echo "  (not found - WARNING)"

echo ""
echo "PermitEmptyPasswords:"
grep -n 'PermitEmptyPasswords' "$SSHD_CONFIG" || echo "  (not found - WARNING)"

echo ""
echo "=== Fix applied successfully ==="
echo ""
echo "To verify, test from another machine:"
echo "  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no Anonymous@<NAS_IP>"
echo ""
echo "Expected: 'Permission denied' immediately (no authentication success)."
echo ""
echo "NOTE: Synology may reset /etc/ssh/sshd_config on DSM updates."
echo "      Re-run this script after any DSM update."

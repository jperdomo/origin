#!/bin/bash
set -e

# Tailscale IPs
VOYAGER_TS_IP="100.95.118.79"
VOYAGER_HOSTNAME="voyager"
MSA01_TS_IP="100.82.202.45"
MSA01_HOSTNAME="ms-a01"

# --- Pre-flight checks ---

echo "==> Running pre-flight checks..."

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

if ! command -v pvecm &>/dev/null; then
  echo "ERROR: pvecm not found. Is this a Proxmox VE node?"
  exit 1
fi

if ! tailscale status &>/dev/null; then
  echo "ERROR: Tailscale is not running. Start it with: tailscale up"
  exit 1
fi

CURRENT_HOSTNAME=$(hostname)
if [ "${CURRENT_HOSTNAME}" != "${VOYAGER_HOSTNAME}" ]; then
  echo "WARNING: Hostname is '${CURRENT_HOSTNAME}', expected '${VOYAGER_HOSTNAME}'."
  echo "         Proxmox uses the hostname for cluster identity."
  read -rp "         Continue anyway? [y/N] " yn
  case "$yn" in [Yy]*) ;; *) exit 1 ;; esac
fi

if pvecm status 2>&1 | grep -q "Cluster information"; then
  echo "ERROR: This node is already in a cluster."
  echo "       Run 'pvecm status' to see current cluster state."
  exit 1
fi

echo "    Pre-flight checks passed."

# --- Connectivity checks ---

echo "==> Checking connectivity to ms-a01 (${MSA01_TS_IP})..."
if ! ping -c 3 -W 5 "${MSA01_TS_IP}" &>/dev/null; then
  echo "ERROR: Cannot ping ms-a01 at ${MSA01_TS_IP}."
  echo "       Verify Tailscale is running on both nodes."
  exit 1
fi
echo "    Ping OK."

echo "==> Testing SSH to root@${MSA01_TS_IP}..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${MSA01_TS_IP}" echo ok &>/dev/null; then
  echo "ERROR: SSH to root@${MSA01_TS_IP} failed."
  echo "       Set up SSH keys first:"
  echo "         ssh-copy-id root@${MSA01_TS_IP}"
  exit 1
fi
echo "    SSH OK."

# Check corosync transport on master
echo "==> Checking corosync transport on ms-a01..."
TRANSPORT=$(ssh -o ConnectTimeout=5 "root@${MSA01_TS_IP}" \
  "grep -oP 'transport:\s*\K\w+' /etc/pve/corosync.conf 2>/dev/null || echo 'unknown'")
if [ "${TRANSPORT}" = "unknown" ]; then
  echo "    Could not read corosync.conf on ms-a01 (may be a single-node cluster)."
elif [ "${TRANSPORT}" != "udpu" ]; then
  echo "WARNING: Corosync transport is '${TRANSPORT}', not 'udpu'."
  echo "         Clustering over Tailscale requires unicast (udpu) transport."
  echo "         Edit /etc/pve/corosync.conf on ms-a01 and change transport to 'udpu'."
  exit 1
else
  echo "    Transport is udpu. OK."
fi

# --- Setup ---

echo "==> Updating /etc/hosts..."
grep -q "${MSA01_TS_IP}.*${MSA01_HOSTNAME}" /etc/hosts 2>/dev/null \
  || echo "${MSA01_TS_IP}  ${MSA01_HOSTNAME}" >> /etc/hosts
grep -q "${VOYAGER_TS_IP}.*${VOYAGER_HOSTNAME}" /etc/hosts 2>/dev/null \
  || echo "${VOYAGER_TS_IP}  ${VOYAGER_HOSTNAME}" >> /etc/hosts
echo "    /etc/hosts updated."

echo "==> Verifying hostname resolution..."
MSA01_RESOLVED=$(getent hosts "${MSA01_HOSTNAME}" | awk '{print $1}')
VOYAGER_RESOLVED=$(getent hosts "${VOYAGER_HOSTNAME}" | awk '{print $1}')

if [ "${MSA01_RESOLVED}" != "${MSA01_TS_IP}" ]; then
  echo "ERROR: ${MSA01_HOSTNAME} resolves to '${MSA01_RESOLVED}', expected '${MSA01_TS_IP}'."
  echo "       Check /etc/hosts for conflicting entries."
  exit 1
fi
if [ "${VOYAGER_RESOLVED}" != "${VOYAGER_TS_IP}" ]; then
  echo "ERROR: ${VOYAGER_HOSTNAME} resolves to '${VOYAGER_RESOLVED}', expected '${VOYAGER_TS_IP}'."
  echo "       Check /etc/hosts for conflicting entries."
  exit 1
fi
echo "    Resolution OK."

echo "==> Opening corosync ports from ms-a01 (${MSA01_TS_IP})..."
iptables -C INPUT -s "${MSA01_TS_IP}" -p udp --dport 5405:5412 -j ACCEPT 2>/dev/null \
  || iptables -A INPUT -s "${MSA01_TS_IP}" -p udp --dport 5405:5412 -j ACCEPT
iptables -C INPUT -s "${MSA01_TS_IP}" -p tcp --dport 22 -j ACCEPT 2>/dev/null \
  || iptables -A INPUT -s "${MSA01_TS_IP}" -p tcp --dport 22 -j ACCEPT
echo "    Firewall rules added."

# --- Join cluster ---

echo ""
echo "==> Joining cluster on ms-a01 (${MSA01_TS_IP})..."
echo "    You may be prompted for the root password of ms-a01."
echo ""
pvecm add "${MSA01_TS_IP}" --link0 "${VOYAGER_TS_IP}"

# --- Verification ---

echo ""
echo "==> Verifying cluster membership..."
pvecm status
echo ""
pvecm nodes

echo ""
echo "==> Successfully joined the cluster!"
echo "    Proxmox Web UI:"
echo "      ms-a01:  https://${MSA01_TS_IP}:8006"
echo "      voyager: https://${VOYAGER_TS_IP}:8006"

#!/bin/bash
set -e

# Tailscale node identities — set these in the environment (or a gitignored
# config sourced before running). No real addresses live in this repo.
: "${VOYAGER_TS_IP:?set VOYAGER_TS_IP (e.g. export VOYAGER_TS_IP=100.x.y.z)}"
: "${VOYAGER_HOSTNAME:?set VOYAGER_HOSTNAME}"
: "${MSA01_TS_IP:?set MSA01_TS_IP}"
: "${MSA01_HOSTNAME:?set MSA01_HOSTNAME}"

echo "==> Updating /etc/hosts with Tailscale IPs..."
grep -q "${VOYAGER_TS_IP}.*${VOYAGER_HOSTNAME}" /etc/hosts 2>/dev/null \
  || echo "${VOYAGER_TS_IP}  ${VOYAGER_HOSTNAME}" >> /etc/hosts
grep -q "${MSA01_TS_IP}.*${MSA01_HOSTNAME}" /etc/hosts 2>/dev/null \
  || echo "${MSA01_TS_IP}  ${MSA01_HOSTNAME}" >> /etc/hosts
echo "    /etc/hosts updated."

echo "==> Opening corosync ports from voyager (${VOYAGER_TS_IP})..."
iptables -C INPUT -s "${VOYAGER_TS_IP}" -p udp --dport 5405:5412 -j ACCEPT 2>/dev/null \
  || iptables -A INPUT -s "${VOYAGER_TS_IP}" -p udp --dport 5405:5412 -j ACCEPT
iptables -C INPUT -s "${VOYAGER_TS_IP}" -p tcp --dport 22 -j ACCEPT 2>/dev/null \
  || iptables -A INPUT -s "${VOYAGER_TS_IP}" -p tcp --dport 22 -j ACCEPT
echo "    Firewall rules added."

echo "==> Verifying Tailscale connectivity to voyager..."
ping -c 2 "${VOYAGER_TS_IP}"

echo ""
echo "==> Master is ready. Now run join-cluster.sh on voyager."

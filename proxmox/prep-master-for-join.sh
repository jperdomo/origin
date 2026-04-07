#!/bin/bash
set -e

# Tailscale IPs
VOYAGER_TS_IP="100.95.118.79"
VOYAGER_HOSTNAME="voyager"
MSA01_TS_IP="100.82.202.45"
MSA01_HOSTNAME="ms-a01"

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

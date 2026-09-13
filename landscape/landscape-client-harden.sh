#!/bin/bash
# landscape-client-harden.sh — run as root ON a fleet client.
# 1) exchange_interval=300 fallback (ping fast path is primary; this is burst insurance)
# 2) shutdown_delay 120 -> 10s (success ack is sent BEFORE the delay; safe)
# 3) restart landscape-client and verify.
set -euo pipefail

CONF=/etc/landscape/client.conf
SM=/usr/lib/python3/dist-packages/landscape/client/manager/shutdownmanager.py
[ -f "$SM" ] || SM=$(find /usr/lib/python3* -name shutdownmanager.py -path "*landscape*" 2>/dev/null | head -1)

grep -q '^exchange_interval' "$CONF" || printf '\nexchange_interval = 300\n' >> "$CONF"
sed -i 's/shutdown_delay=120/shutdown_delay=10/' "$SM"

systemctl restart landscape-client
sleep 3
echo "client-conf:"; grep exchange_interval "$CONF"
echo "delay-line: $(grep -o 'shutdown_delay=[0-9]*' "$SM" | head -1)"
echo "service: $(systemctl is-active landscape-client)"

#!/bin/bash
# landscape-license-roll.sh — restore full management (Shutdown/Reboot) on a
# Landscape client that was accepted UNLICENSED.
#
# Why: a standalone account licenses by seat. Any computer accepted while the
# legacy pool is exhausted (or before Pro info was reported) lands UNLICENSED,
# which strips the action buttons and OS info in the UI. This attaches the
# free Ubuntu Pro subscription and forces the server to re-classify.
#
# Run as root ON THE CLIENT. No server access needed; the server self-heals.
#
# Usage: sudo -v && UBUNTU_PRO_TOKEN=<token> bash landscape-license-roll.sh
#
# Exit codes: 0 = full chain OK; 1 = attach failed; 2 = client not active after restart.
set -u

: "${UBUNTU_PRO_TOKEN:?Set UBUNTU_PRO_TOKEN to the free-personal Pro token}"
DATA=/var/lib/landscape/client
PERSIST="$DATA/ubuntu-pro-info.manager.bpkl"

echo "== [1/4] pro attach"
pro attach "$UBUNTU_PRO_TOKEN"
if [ $? -ne 0 ] && ! pro status --format json 2>/dev/null | grep -q '"attached": true'; then
  echo "attach failed or not attached; aborting" >&2
  exit 1
fi

echo "== [2/4] pro enable landscape (ignoring 'already enabled' exit 1)"
pro enable landscape 2>&1 || true

echo "== [3/4] drop data-watcher persist (forces re-send of pro info)"
rm -f "$PERSIST"

echo "== [4/4] restart landscape-client"
systemctl restart landscape-client
sleep 4
systemctl is-active landscape-client || { echo "client not active" >&2; exit 2; }

echo "OK: attached, persist dropped, client active."
echo "Server flips license_type 0->1 on the next ubuntu-pro-info send (up to ~15 min)."
echo "Verify in the Landscape DB: license_type=1 (FREE_PRO), ubuntu_pro_info.attached=true."

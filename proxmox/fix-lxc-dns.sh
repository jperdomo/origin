#!/bin/bash
set -e

# Point an LXC at a real resolver.
#
# When the PVE host runs Tailscale with MagicDNS overriding local DNS, the host's
# /etc/resolv.conf points at 100.100.100.100. Containers created without an explicit
# nameserver inherit that (the "# --- BEGIN PVE ---" block). Quad100 is device-local
# to tailscaled, so in a container that isn't on the tailnet nothing answers and every
# DNS query hangs -- apt shows "Ign:" on InRelease then sits at "Connecting to
# archive.ubuntu.com" with no IP, which reads like a broken template but isn't.

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    echo "'pct' not found. Run this on the Proxmox host, not inside the container."
    exit 1
fi

echo "==> Containers on this host:"
pct list

read -r -p "Container ID to fix: " CTID
if ! pct config "$CTID" >/dev/null 2>&1; then
    echo "No such container: ${CTID}"
    exit 1
fi

CURRENT=$(pct config "$CTID" | awk -F': ' '/^nameserver:/ {print $2}')
echo "==> Current nameserver: ${CURRENT:-<inherits host settings>}"

# The host's default gateway is nearly always the LAN resolver too.
GATEWAY=$(ip route show default | awk '{print $3; exit}')
read -r -p "Nameserver to set [${GATEWAY}]: " DNS
DNS="${DNS:-$GATEWAY}"

if [ -z "$DNS" ]; then
    echo "No nameserver given and no default gateway detected. Aborting."
    exit 1
fi

echo "==> Setting nameserver ${DNS} on container ${CTID}..."
pct set "$CTID" --nameserver "$DNS"
echo "    Config updated."

# PVE regenerates the container's resolv.conf at start, so the change needs a restart
# to land. Editing resolv.conf in the container instead would be overwritten anyway.
if [ "$(pct status "$CTID")" = "status: running" ]; then
    read -r -p "Reboot container ${CTID} to apply? [y/N]: " REPLY
    case "$REPLY" in
        [yY]*)
            echo "==> Rebooting ${CTID}..."
            pct reboot "$CTID"
            echo "==> Verifying DNS from inside the container..."
            if pct exec "$CTID" -- timeout 10 getent hosts archive.ubuntu.com; then
                echo "    DNS is working. apt should run clean now."
            else
                echo "    Still failing. Check that ${DNS} is reachable from the container's subnet."
                exit 1
            fi
            ;;
        *)
            echo "==> Skipped. Run 'pct reboot ${CTID}' to apply."
            ;;
    esac
else
    echo "==> Container is not running. The new nameserver applies on next start."
fi

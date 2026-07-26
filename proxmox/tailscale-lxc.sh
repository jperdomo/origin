#!/bin/bash
set -e

# Allow Tailscale (or any WireGuard userspace) to run inside an LXC.
#
# tailscaled needs /dev/net/tun, and a container does not get it by default. Without
# it the daemon starts, fails to create the TUN device, and exits -- systemd retries
# five times then gives up with "Start request repeated too quickly", so the symptom
# is a dead tailscaled and not an obvious missing-device error. Unprivileged
# containers need both lines below: the cgroup2 rule to permit char device 10:200,
# and the bind mount to actually expose it.
#
# Usage:
#   ./tailscale-lxc.sh          # pick a container from a menu
#   ./tailscale-lxc.sh 102      # non-interactive, for ssh/automation

LINE1="lxc.cgroup2.devices.allow: c 10:200 rwm"
LINE2="lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    echo "'pct' not found. Run this on the Proxmox host, not inside the container."
    exit 1
fi

# Nothing to bind-mount if the host itself lacks the device.
if [ ! -c /dev/net/tun ]; then
    echo "/dev/net/tun is missing on the host. Load it with 'modprobe tun' first."
    exit 1
fi

CTID="$1"
if [ -z "$CTID" ]; then
    echo "==> Containers on this host:"
    pct list
    read -r -p "Container ID to enable TUN on: " CTID
fi

if ! pct config "$CTID" >/dev/null 2>&1; then
    echo "No such container: ${CTID}"
    exit 1
fi

CONF="/etc/pve/lxc/${CTID}.conf"
if [ ! -f "$CONF" ]; then
    echo "Config not found: ${CONF}"
    exit 1
fi

if grep -Fxq "$LINE1" "$CONF" && grep -Fxq "$LINE2" "$CONF"; then
    echo "==> Already configured in ${CONF}. Nothing to change."
    ALREADY=yes
else
    # Appended separately so a config with only one of the two lines gets repaired
    # rather than ending up with a duplicate.
    grep -Fxq "$LINE1" "$CONF" || echo "$LINE1" >> "$CONF"
    grep -Fxq "$LINE2" "$CONF" || echo "$LINE2" >> "$CONF"
    echo "==> Added TUN passthrough to ${CONF}."
    ALREADY=no
fi

# The mount entry is applied at container start, so an edit alone changes nothing
# for a running container. This is the step that is easy to miss.
if [ "$(pct status "$CTID")" = "status: running" ]; then
    if pct exec "$CTID" -- test -c /dev/net/tun 2>/dev/null; then
        echo "==> /dev/net/tun is already present inside ${CTID}. No restart needed."
        exit 0
    fi

    if [ "$ALREADY" = "yes" ]; then
        echo "==> Config is correct but the container has not been restarted since."
    fi

    read -r -p "Restart container ${CTID} now to apply? [y/N]: " REPLY
    case "$REPLY" in
        [yY]*)
            echo "==> Restarting ${CTID}..."
            pct reboot "$CTID"
            echo "==> Verifying /dev/net/tun inside the container..."
            if pct exec "$CTID" -- test -c /dev/net/tun; then
                echo "    /dev/net/tun is present."
                echo "    Next: pct exec ${CTID} -- tailscale up"
            else
                echo "    Still missing. Check that the container is unprivileged as expected."
                exit 1
            fi
            ;;
        *)
            echo "==> Skipped. Run 'pct reboot ${CTID}' to apply."
            ;;
    esac
else
    echo "==> Container is not running. The device appears on next start."
fi

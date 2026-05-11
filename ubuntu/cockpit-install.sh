#!/bin/bash
# Cockpit installer for Ubuntu 26.04 LTS (resolute)
# Modules: Files (official cockpit-files), VMs (cockpit-machines), Podman (cockpit-podman)
# Metrics: full PCP integration (live + historical graphs)
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"

sudo apt update

sudo apt install -y \
    cockpit \
    cockpit-files \
    pcp \
    pcp-zeroconf \
    cockpit-machines \
    libvirt-daemon-system libvirt-clients \
    qemu-system-x86 virtinst bridge-utils virtiofsd \
    cockpit-podman \
    podman \
    acl

sudo systemctl enable --now cockpit.socket
sudo systemctl enable --now pmcd pmlogger
sudo systemctl enable --now libvirtd
sudo systemctl enable --now podman.socket

sudo usermod -aG libvirt,kvm "$TARGET_USER"

# Ensure libvirt 'default' storage pool exists, is active, and autostarts
POOL_NAME=default
POOL_PATH=/var/lib/libvirt/images
if ! sudo virsh pool-info "$POOL_NAME" >/dev/null 2>&1; then
    sudo virsh pool-define-as "$POOL_NAME" dir --target "$POOL_PATH"
    sudo virsh pool-build "$POOL_NAME" 2>/dev/null || true
fi
if [ "$(sudo virsh pool-info "$POOL_NAME" | awk '/^State:/ {print $2}')" != "running" ]; then
    sudo virsh pool-start "$POOL_NAME"
fi
sudo virsh pool-autostart "$POOL_NAME" >/dev/null

# Let QEMU/virtiofsd (running as libvirt-qemu) traverse into the user's home so
# virtiofs shares of any subdirectory are readable from guests. Home dirs default
# to 0750, which blocks libvirt-qemu from descending into them.
TARGET_HOME=$(getent passwd "$TARGET_USER" | awk -F: '{print $6}')
if [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME" ]; then
    sudo setfacl -m u:libvirt-qemu:rx "$TARGET_HOME"
fi

# Optional: grant recursive read on specific dirs meant to be shared via virtiofs.
# Pass a colon-separated list via VIRTIOFS_SHARES, e.g.:
#   VIRTIOFS_SHARES="$HOME/infosec:$HOME/projects" ./cockpit-install.sh
if [ -n "${VIRTIOFS_SHARES:-}" ]; then
    IFS=':' read -ra _shares <<<"$VIRTIOFS_SHARES"
    for _s in "${_shares[@]}"; do
        if [ -d "$_s" ]; then
            sudo setfacl -R -m u:libvirt-qemu:rx "$_s"
        fi
    done
fi

if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 9090/tcp
fi

echo "Cockpit installed. Log out/in so group changes (libvirt, kvm) take effect for $TARGET_USER."
echo "virtiofs: libvirt-qemu has rx on $TARGET_HOME (shares under it will be readable from guests)."
echo "Open: https://$(hostname -I | awk '{print $1}'):9090"

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
    qemu-system-x86 virtinst bridge-utils \
    cockpit-podman \
    podman

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

if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 9090/tcp
fi

echo "Cockpit installed. Log out/in so group changes (libvirt, kvm) take effect for $TARGET_USER."
echo "Open: https://$(hostname -I | awk '{print $1}'):9090"

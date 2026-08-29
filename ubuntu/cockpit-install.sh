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

# Grant libvirt-qemu/virtiofsd read access ONLY on explicitly listed share
# dirs — never the whole home directory. Pass a colon-separated list via
# VIRTIOFS_SHARES, e.g.:
#   VIRTIOFS_SHARES="$HOME/infosec:$HOME/projects" ./cockpit-install.sh
if [ -n "${VIRTIOFS_SHARES:-}" ]; then
    IFS=':' read -ra _shares <<<"$VIRTIOFS_SHARES"
    for _s in "${_shares[@]}"; do
        if [ -d "$_s" ]; then
            sudo setfacl -R -m u:libvirt-qemu:rx "$_s"
        fi
    done
else
    echo "NOTE: no VIRTIOFS_SHARES set — libvirt-qemu has no access to your home."
    echo "      To share dirs via virtiofs, re-run with:"
    echo "        VIRTIOFS_SHARES=\"\$HOME/dir1:\$HOME/dir2\" $0"
fi

if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 9090/tcp
fi

echo "Cockpit installed. Log out/in so group changes (libvirt, kvm) take effect for $TARGET_USER."
echo "virtiofs: libvirt-qemu has rx only on dirs listed in VIRTIOFS_SHARES."
echo "Open: https://$(hostname -I | awk '{print $1}'):9090"

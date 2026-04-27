#!/bin/bash
# Podman deployer for Ubuntu 26.04 LTS (resolute)
# Installs: podman, docker CLI shim (podman-docker), podman-compose, cockpit-podman
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"

sudo apt update

sudo apt install -y \
    podman \
    podman-docker \
    podman-compose \
    cockpit-podman

sudo systemctl enable --now podman.socket

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
BASHRC="$TARGET_HOME/.bashrc"
if ! grep -q 'PODMAN_COMPOSE_PROVIDER=podman-compose' "$BASHRC"; then
    echo 'export PODMAN_COMPOSE_PROVIDER=podman-compose' | sudo -u "$TARGET_USER" tee -a "$BASHRC" >/dev/null
fi

echo "Podman installed. 'docker' and 'podman' are interchangeable; compose via 'docker compose' or 'podman-compose'."

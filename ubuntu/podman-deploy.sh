#!/bin/bash
set -e

sudo apt install -y podman podman-docker podman-compose cockpit-podman

if ! grep -q 'PODMAN_COMPOSE_PROVIDER=podman-compose' "$HOME/.bashrc"; then
  echo 'export PODMAN_COMPOSE_PROVIDER=podman-compose' >> "$HOME/.bashrc"
fi
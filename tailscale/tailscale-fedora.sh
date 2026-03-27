#!/bin/bash
set -e
# Fedora (DNF5+ changed --add-repo syntax to addrepo --from-repofile=)
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install -y tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
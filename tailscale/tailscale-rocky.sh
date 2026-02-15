#!/bin/bash
set -e

# Root Check
if [ "$EUID" -eq 0 ]; then
  echo "You have ROOT access.

Tailscale RHEL9 Install starting...

"
sleep 3

#RHEL 9 Repo
dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo

# Install
dnf install -y tailscale
systemctl enable --now tailscaled
tailscale up

else
echo "

[ MUST RUN AS ROOT! ]

"
fi

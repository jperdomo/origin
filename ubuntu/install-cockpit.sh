#!/bin/bash

# Update
sudo apt-get update -y

# Install Cockpit
sudo apt-get install cockpit podman cockpit-podman pcp cockpit-pcp -y

# 45 Drives Repo + Cockpit Navigator
curl -sSL https://repo.45drives.com/setup -o setup-repo.sh
sudo bash setup-repo.sh

sudo apt install cockpit-navigator -y

# Enable and start the Cockpit service
sudo systemctl enable --now cockpit.socket

# Firewall + Start
sudo ufw allow 9090/tcp
sudo systemctl start cockpit

# Done
echo "Cockpit is now installed and enabled"

#!/bin/bash

# Update
sudo apt-get update -y

# Install Cockpit
sudo apt-get install cockpit podman cockpit-podman cockpit-pcp -y

# Enable and start the Cockpit service
sudo systemctl enable --now cockpit.socket

# Firewall + Start
sudo ufw allow 9090/tcp
sudo systemctl start cockpit

# Done
echo "Cockpit is now installed and enabled"

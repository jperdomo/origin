#!/bin/bash

# Install OpenSSH server
sudo dnf install -y openssh-server

# Enable and start sshd service
sudo systemctl enable --now sshd

# Configure firewall to allow SSH
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# Verify installation
echo "SSH service status:"
systemctl status sshd --no-pager
echo "

SSH is now installed and enabled"

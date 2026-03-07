#!/bin/bash
# Install and configure Avahi (mDNS) for .local hostname resolution

sudo yum install -y avahi avahi-tools
sudo hostnamectl set-hostname gamma-openbao
sudo systemctl enable --now avahi-daemon
sudo firewall-cmd --permanent --add-service=mdns
sudo firewall-cmd --reload

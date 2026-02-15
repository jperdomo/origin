#!/bin/bash
set -e

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
firewall-cmd --permanent --add-masquerade

# Advertise Routes
echo "Enter subnet routes to advertise (e.g. 192.168.1.0/24,192.168.2.0/24):"
read -r subnets
sudo tailscale up --advertise-routes="$subnets"

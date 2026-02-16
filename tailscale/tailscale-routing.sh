#!/bin/bash
set -e

# Enable IP forwarding
sudo tee /etc/sysctl.d/99-tailscale.conf > /dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
sudo firewall-cmd --permanent --add-masquerade

# Advertise Routes
echo "Enter subnet routes to advertise (e.g. 192.168.1.0/24,192.168.2.0/24):"
read -r subnets
if [ -z "$subnets" ]; then
    echo "Subnet routes cannot be empty."
    exit 1
fi
sudo tailscale up --advertise-routes="$subnets"

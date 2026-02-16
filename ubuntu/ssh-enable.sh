#!/bin/bash
set -e

# Check that we're root; if not, fail out
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Update + Install
apt update -y

apt install -y openssh-server ufw

systemctl enable ssh

systemctl start ssh

systemctl status ssh

ufw allow ssh

# Harden SSH
tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
X11Forwarding no
EOF

systemctl restart ssh

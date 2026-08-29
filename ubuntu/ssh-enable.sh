#!/bin/bash
set -e

# Check that we're root; if not, fail out
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Update + Install
apt update -y

apt install -y openssh-server ufw ssh-import-id

systemctl enable ssh

systemctl start ssh

systemctl status ssh

ufw allow ssh

# Import authorized keys from GitHub (optional)
read -r -p "GitHub username to import SSH keys from (blank to skip): " gh_user
if [ -n "$gh_user" ]; then
    target_user="${SUDO_USER:-$USER}"
    sudo -u "$target_user" ssh-import-id "gh:$gh_user"
fi

# Allow password login? (default: no — key auth only)
read -r -p "Allow password authentication? [y/N]: " allow_pw
if [[ "$allow_pw" =~ ^[Yy]$ ]]; then
    pw_auth="yes"
else
    pw_auth="no"
fi

# Harden SSH
tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<EOF
PermitRootLogin no
PasswordAuthentication $pw_auth
MaxAuthTries 3
X11Forwarding no
EOF

systemctl restart ssh

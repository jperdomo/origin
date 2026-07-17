#!/bin/bash
set -e

# Check that we're root; if not, fail out
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# sudo is not in every minimal LXC/cloud template
if ! command -v sudo > /dev/null; then
    apt-get update -y
    apt-get install -y sudo
fi

read -r -p "Username to create: " username
if [ -z "$username" ]; then
    echo "Username cannot be empty."
    exit 1
fi

if id "$username" > /dev/null 2>&1; then
    echo "User '$username' already exists; adding to sudo group only."
else
    useradd --create-home --shell /bin/bash "$username"
    passwd "$username"
fi

usermod -aG sudo "$username"

# Passwordless sudo? (default: no)
read -r -p "Allow passwordless sudo for $username? [y/N]: " nopasswd
if [[ "$nopasswd" =~ ^[Yy]$ ]]; then
    echo "$username ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$username"
    chmod 0440 "/etc/sudoers.d/90-$username"
    visudo -cf "/etc/sudoers.d/90-$username"
fi

# Import authorized keys from GitHub (optional)
read -r -p "GitHub username to import SSH keys from (blank to skip): " gh_user
if [ -n "$gh_user" ]; then
    if ! command -v ssh-import-id > /dev/null; then
        apt-get update -y
        apt-get install -y ssh-import-id
    fi
    sudo -u "$username" ssh-import-id "gh:$gh_user"
fi

echo "✅ User '$username' created."
id "$username"

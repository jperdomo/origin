#!/bin/bash

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
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
#!/bin/bash

# Check that /etc/apt exists; if not, this isn't a valid distro for this script
if [[ ! -d /etc/apt ]]; then
    echo "This script is for Debian-based distributions using APT only."
    echo "See our downloads page at https://jellyfin.org/downloads/server for more options."
    exit 1
fi

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Update + Install
apt update -y

apt install -y \
lf \
git \
gh \
nano \
curl \
htop \
bmon \
btop \
stress \
neofetch \
iputils-ping \
net-tools \
nfs-common
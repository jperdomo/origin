#!/bin/bash

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Update + Install
apt update -y

apt install -y \
sudo \
git \
gh \
nano \
curl \
htop \
bmon \
btop \
stress \
neofetch \
iperf \
iputils-ping \
net-tools \
nfs-common
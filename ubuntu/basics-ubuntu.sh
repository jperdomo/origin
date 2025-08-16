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
iperf \
iputils-ping \
net-tools \
nfs-common

# Fastfetch
apt install software-properties-common -y
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
apt update -y
apt install -y fastfetch
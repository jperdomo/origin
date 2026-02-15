#!/bin/bash
set -e

# Check that we're root; if not, fail out
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Update + Install
apt-get update -y
apt-get install -y \
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
net-tools

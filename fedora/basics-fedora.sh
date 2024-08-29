#!/bin/bash
# Prep
sudo dnf install -y epel-release

# Install
sudo dnf install -y \
git \
nano \
htop \
btop \
bmon \
curl \
stress \
neofetch \
iputils \
nfs-utils

# Speedtest
#curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
#sudo dnf install -y speedtest
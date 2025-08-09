#!/bin/bash
# Prep
dnf update
dnf install -y epel-release

# Install
dnf install -y \
git \
gh \
clear \
sudo \
nano \
htop \
btop \
bmon \
curl \
stress \
fastfetch \
iputils \
nfs-utils
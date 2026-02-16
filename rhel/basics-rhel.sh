#!/bin/bash
set -e

# Root Check
if [ "$EUID" -eq 0 ]; then
  echo "You have ROOT access."

#Prep
dnf config-manager --set-enabled crb
dnf install -y epel-release --allowerasing

#Update
dnf update -y

#Install
dnf install -y --allowerasing \
sudo \
git \
gh \
nano \
htop \
btop \
bmon \
curl \
stress \
fastfetch \
iputils \
nfs-utils

else
echo "

[ MUST RUN AS ROOT! ]

"
exit 1
fi

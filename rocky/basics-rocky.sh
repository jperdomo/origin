#!/bin/bash

# Root Check
if [ "$UID" -eq 0 ]; then
  echo "You have ROOT access."
   
#Prep
dnf config-manager --set-enabled crb
dnf install -y epel-release --allowerasing

#Update
dnf update -y

#Install
dnf install -y --allowerasing \
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

#Speedtest
#curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash
#dnf install -y speedtest

else
echo "

[ MUST RUN AS ROOT! ]

"
fi
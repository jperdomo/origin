#!/bin/bash
set -e
#Update
sudo dnf upgrade --refresh -y

#Install
sudo dnf install -y dnf-plugins-core
sudo dnf install -y cockpit cockpit-selinux cockpit-pcp cockpit-navigator

#Enable Services
sudo systemctl start cockpit cockpit.socket
sudo systemctl enable cockpit cockpit.socket

#Status
systemctl status cockpit

#Firewall
sudo firewall-cmd --permanent --add-service=cockpit
sudo firewall-cmd --reload
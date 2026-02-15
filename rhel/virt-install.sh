#!/bin/bash
set -e
sudo dnf install -y @virtualization
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
#!/bin/bash
#Set User
target=/etc/libvirt/qemu.conf
#target=test
sudo echo :sudo required:
sudo echo -e 'user = "jperdomo" \ngroup = "libvirt"' >> $target
#Restart libvirtd
sudo systemctl restart libvirtd
sudo usermod -aG libvirt $(whoami)

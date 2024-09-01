#!/bin/bash

apt install pve-headers-$(uname -r)

curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg –dearmor | tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1

apt update

apt install dirmngr ca-certificates software-properties-common apt-transport-https dkms curl -y

echo ‘deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /’ | tee /etc/apt/sources.list.d/nvidia-drivers.list

apt install nvidia-driver cuda nvidia-smi nvidia-settings nvtop

apt install nvidia-container-toolkit

nvidia-ctk runtime configure –runtime=docker

echo"
##############################################
   Reboot Required to complete installation
##############################################"

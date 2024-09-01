#!/bin/bash

apt update

apt install pve-headers-$(uname -r)

curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --dearmor > /usr/share/keyrings/nvidia-drivers.gpg

apt install dirmngr ca-certificates software-properties-common apt-transport-https dkms curl -y

apt update

echo "deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ ./" | tee /etc/apt/sources.list.d/nvidia-drivers.list

apt update

apt install nvidia-driver cuda nvidia-smi nvidia-settings nvtop -y

apt install nvidia-container-toolkit -y

nvidia-ctk runtime configure –runtime=docker

echo "
##############################################
   Reboot Required to complete installation
##############################################
"

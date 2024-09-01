#!/bin/bash

apt update

apt install pve-headers-$(uname -r)

#curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --dearmor | tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1
#curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --import
#echo "nvidia-dep-11" > /etc/apt/sources.list.d/nvidia-drivers.list
#curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --import
#cat << EOF > /etc/apt/sources.list.d/nvidia-drivers.list
#deb http://download.nvidia.com/debian12 11.1 non-free
#EOF
#curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --import | tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1
#curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --dearmor | tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1

curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | gpg --dearmor > /usr/share/keyrings/nvidia-drivers.gpg

apt install dirmngr ca-certificates software-properties-common apt-transport-https dkms curl -y

apt update

# Add the new repository to the sources list with proper formatting
echo "deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ ./" | tee /etc/apt/sources.list.d/nvidia-drivers.list

# Update the package index to include the new repository
apt update

apt install nvidia-driver cuda nvidia-smi nvidia-settings nvtop -y

apt install nvidia-container-toolkit -y

#nvidia-ctk runtime configure –runtime=docker

echo "
##############################################
   Reboot Required to complete installation
##############################################
"

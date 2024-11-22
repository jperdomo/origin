#!/bin/bash

# Check if OS is Debian or Ubuntu
if [ "$(uname -s)" != "Linux" ]; then
    echo "This script must be run on Linux."
    exit 1
fi

if [[ "$UNAME_SYS" == "GNU/Linux"* ]]; then
    if [ "$UNAME Release" != "Debian GNU/Linux"* ] && [ "$UNAME_RELEASE" != "Ubuntu"* ]; then
        echo "This script must be run on Debian or Ubuntu."
        exit 1
    fi
fi

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# Ask user to input the mount point directory
read -p "Enter the name of the mount point: " mount_point

# Config mount point
if [ ! -d "$mount_point" ]; then
  # Create the mount point if it doesn't exist
  MNT=/mnt/$mount_point
  mkdir -p $MNT
fi

echo "The mount folder of MNT is $MNT"

# Ask for the user to input the IP address of the NAS
read -p "Enter the IP address of the remote source: " ip_address

# Ask for the user to input the username of the NAS
read -p "Enter the IP address of the remote folder (ex. /volume2/Media): " folder
echo "$ip_address:$folder $MNT nfs vers=3,nouser,atime,auto,retrans=2,rw,dev,exec 0 0" >> /etc/fstab
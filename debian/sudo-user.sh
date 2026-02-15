#!/bin/bash

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# sudo user

echo "Username that will be make sudo"

read -r user

adduser "$user"
usermod -aG sudo "$user"
newgrp sudo

echo "$user added the following:"
groups "$user"

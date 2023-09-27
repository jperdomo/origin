#!/bin/bash

# Check that we're root; if not, fail out
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# sudo user

echo "Username to create + sudo"
read -r user

useradd -m -s /bin/bash -G sudo $user

#usermod -aG sudo $user
#newgrp sudo

echo "
========================================
$user added the following:
========================================"
groups $user
echo "
"
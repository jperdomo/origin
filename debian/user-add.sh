#!/bin/bash
set -e

# Check that we're root; if not, fail out
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

# sudo user

echo "Username to create + sudo"
read -r user
if [ -z "$user" ] || [[ "$user" =~ ^- ]]; then
    echo "Invalid username."
    exit 1
fi

useradd -m -s /bin/bash -G sudo "$user"

#usermod -aG sudo $user
#newgrp sudo

echo "
========================================
$user added the following:
========================================"
groups "$user"
echo "
"

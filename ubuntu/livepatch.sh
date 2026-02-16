#!/bin/bash
set -e

# Ask for token
echo "Provide your Ubuntu Live Patch Token:"
read -rs token
echo ""
if [ -z "$token" ]; then
    echo "Token cannot be empty."
    exit 1
fi

# Configure Live Patching
sudo snap install canonical-livepatch
sudo canonical-livepatch enable "$token"

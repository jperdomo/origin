#!/bin/bash

# Ask for token
echo "Provide your Ubuntu Live Patch Token:"
read token

# Configure Live Patching
sudo snap install canonical-livepatch
sudo canonical-livepatch enable $token
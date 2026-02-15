#!/bin/bash
set -e

# Check for REAL security updates available
sudo apt update
sudo apt list --upgradable

# Check Ubuntu Security Notices (USN) affecting your system
ubuntu-security-status

# Or install and use
#sudo apt install ubuntu-advantage-tools
#sudo ua security-status
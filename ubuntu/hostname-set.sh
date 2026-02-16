#!/bin/bash
set -e
echo "What is the new hostname?"
read -r hostname
if [ -z "$hostname" ]; then
    echo "Hostname cannot be empty."
    exit 1
fi
hostnamectl set-hostname "$hostname"
echo "hostname set to: $(hostname)"

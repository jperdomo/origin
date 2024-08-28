#!/bin/bash

sudo bash -c '
# Create a backup of the original dnf.conf file
cp -p /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak

# Check if [main] section already has max_parallel_downloads option
if grep "max_parallel_downloads=" /etc/dnf/dnf.conf > /dev/null; then
  echo "Found existing configuration, skipping..."
else
  # Add max_parallel_downloads option to the [main] section
  sed -i 's/^installonly_limit=/installonly_limit=3/g' /etc/dnf/dnf.conf
  sed -i 's/best=False/best=True/g' /etc/dnf/dnf.conf
  echo "max_parallel_downloads=20" >> /etc/dnf/dnf.conf

  # Add fastestmirror option to the [main] section
  if ! grep "fastestmirror=True" /etc/dnf/dnf.conf > /dev/null; then
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
  fi
fi

echo "DNF configuration updated successfully."
'

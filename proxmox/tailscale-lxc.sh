#!/bin/bash
set -e

source="/etc/pve/lxc/"

# Define the values to add
line1="lxc.cgroup2.devices.allow: c 10:200 rwm"
line2="lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"

# Select
cd "$source"
files=(*.conf)
select file in "${files[@]}"; do
  if [[ -n "$file" ]]; then
    # Output
    origin=$(echo "$file" | sed 's/\.conf$//')
    echo "$origin | lxc script running..."
  
    # Check if the lines are already present in the file
    if grep -Fxq "$line1" "$file" && grep -Fxq "$line2" "$file"; then
      echo "Lines are already present in $file"
      break
    else
      # If not, add the lines to the file
      echo "$line1" >> "$file"
      echo "$line2" >> "$file"
      echo "Lines added to $file"
      break
    fi
  else
    echo "Invalid selection. Please choose a valid file."
  fi
done
#!/bin/bash
set -e

# Flatpak
sudo apt install -y \
flatpak \
gnome-software-plugin-flatpak

## Flathub Repo
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Extension Manager
flatpak install flathub com.mattjakeman.ExtensionManager -y

# Done message
echo "Reboot required!"

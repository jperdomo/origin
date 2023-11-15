#!/bin/bash

# Flatpak
sudo apt update
sudo apt install flatpak -y
## Repo + Brave Install
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# VS Code
flatpak install -y flathub com.visualstudio.code

echo "Reboot Required!"
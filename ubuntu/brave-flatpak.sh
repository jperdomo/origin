#!/bin/bash

# Flatpak
sudo apt update
sudo apt install flatpak -y
## Repo + Brave Install
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Brave
flatpak install -y flathub com.brave.Browser
## Default Browser
xdg-settings set default-web-browser com.brave.Browser.desktop

echo "Reboot Required!"
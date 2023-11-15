#!/bin/bash

# Brave

## Flatpak
sudo apt update
sudo apt install flatpak -y
## Repo + Brave Install
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub io.brave.Browser
## Run
flatpak run io.brave.Browser
## Default Browser
xdg-settings set default-web-browser com.brave.Browser.desktop

echo "Reboot Required!"
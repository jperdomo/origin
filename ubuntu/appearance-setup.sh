#!/bin/bash

# Dark Theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

## BKG
color="#333333"
### Set the background color using gsettings
gsettings set org.gnome.desktop.background primary-color "$color"
### Set the background mode to "solid" (to ensure a solid color background)
gsettings set org.gnome.desktop.background picture-options "none"
### Set the background mode to "none" (to ensure no wallpaper is used)
gsettings set org.gnome.desktop.background picture-uri ''

# Terminal
sudo apt update
sudo apt install -y gnome-console

# Gnome Apps
sudo apt install -y gnome-tweaks gnome-shell-extension-manager

# Hide Home Folder
gsettings set org.gnome.shell.extensions.ding show-home false

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

# Favorites
gsettings set org.gnome.shell favorite-apps "['org.gnome.Console.desktop', 'org.gnome.Nautilus.desktop', 'firefox_firefox.desktop']"
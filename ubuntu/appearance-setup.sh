#!/bin/bash

# BKG
color="#333333"

## Set the background color using gsettings
gsettings set org.gnome.desktop.background primary-color "$color"

## Set the background mode to "solid" (to ensure a solid color background)
gsettings set org.gnome.desktop.background picture-options "none"

## Set the background mode to "none" (to ensure no wallpaper is used)
gsettings set org.gnome.desktop.background picture-uri ''

echo "Background color changed to $color"


# Install gnome-extensions-app if not already installed
if ! command -v gnome-extensions-app &> /dev/null; then
    sudo apt update
    sudo apt install gnome-shell-extensions
fi

# Install runcat extension
gnome-extensions install runcat@dracula-at-night.com

# Install forge extension
gnome-extensions install forge@peppercarrot.com

# Install dash to panel extension
gnome-extensions install dash-to-panel@jderose9.github.com

# Enable the installed extensions
gnome-extensions enable runcat@dracula-at-night.com
gnome-extensions enable forge@peppercarrot.com
gnome-extensions enable dash-to-panel@jderose9.github.com

echo "Gnome extensions installed and enabled successfully."
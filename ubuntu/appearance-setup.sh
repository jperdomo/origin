#!/bin/bash
set -e

# Terminal
sudo apt update
sudo apt install -y gnome-console

# Hide Home Folder (only if Desktop Icons NG extension is installed)
if gsettings list-schemas 2>/dev/null | grep -q 'org.gnome.shell.extensions.ding'; then
    gsettings set org.gnome.shell.extensions.ding show-home false
fi

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

# Dark Mode (system-wide, GNOME 48+)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Dark BKG
COLOR='#222222'

gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background picture-uri-dark ''

gsettings set org.gnome.desktop.background primary-color $COLOR
gsettings set org.gnome.desktop.background secondary-color $COLOR

# Favorites
#gsettings set org.gnome.shell favorite-apps "['org.gnome.Console.desktop', 'org.gnome.Nautilus.desktop', 'firefox_firefox.desktop']"
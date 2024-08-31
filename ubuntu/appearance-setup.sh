#!/bin/bash

# Terminal
sudo apt update
sudo apt install -y gnome-console

# Hide Home Folder
gsettings set org.gnome.shell.extensions.ding show-home false

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

# Favorites
#gsettings set org.gnome.shell favorite-apps "['org.gnome.Console.desktop', 'org.gnome.Nautilus.desktop', 'firefox_firefox.desktop']"
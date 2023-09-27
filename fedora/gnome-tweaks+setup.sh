#!/bin/bash

# Gnome tweaks
sudo dnf install -y gnome-tweaks

# Chrome gnome shell
##Might not be needed
#sudo dnf copr -y enable region51/chrome-gnome-shell
#sudo dnf install -y chrome-gnome-shell

# Extension Manager
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.mattjakeman.ExtensionManager

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

#Wallpaper
##Broken :(
#gsettings set org.gnome.desktop.background picture-uri ""
#gsettings set org.gnome.desktop.background primary-color '#333333'
#gsettings set org.gnome.desktop.background color-shading-type 'solid'
#Dock
#Dark Mode
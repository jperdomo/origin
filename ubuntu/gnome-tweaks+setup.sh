#!/bin/bash

# Gnome tweaks
sudo apt install -y gnome-tweaks dconf-editor

#Chrome gnome shell
##Might not be needed
#sudo dnf copr -y enable region51/chrome-gnome-shell
#sudo dnf install -y chrome-gnome-shell

#Extension Manager
#sudo apt install -y flatpak
#flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#flatpak install -y flathub com.mattjakeman.ExtensionManager

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

# Wallpaper
gsettings set org.gnome.desktop.background picture-uri ""
gsettings set org.gnome.desktop.background primary-color '#191919'
gsettings set org.gnome.desktop.background color-shading-type 'solid'

# Dock
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32

# Dark Mode
#gsettings reset org.gnome.shell.ubuntu color-scheme # if changed above
gsettings set org.gnome.shell.ubuntu color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Yaru-dark # Legacy apps, can specify an accent such as Yaru-olive-dark
gsettings set org.gnome.desktop.interface color-scheme prefer-dark # new apps
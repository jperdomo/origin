#/bin/bash
#DNF Install
sudo dnf install dnf-plugins-core -y
sudo dnf install \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf update -y
sudo dnf install steam -y
sudo dnf upgrade --refresh -y
#Flatpak
#sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#sudo flatpak install -y flathub com.valvesoftware.Steam
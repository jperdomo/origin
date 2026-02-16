#!/bin/bash
set -e
sudo dnf update -y
sudo dnf upgrade --refresh -y
sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf update --refresh -y
sudo dnf install akmod-nvidia -y
#Update Repos
sudo dnf groupupdate multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
sudo dnf groupupdate sound-and-video -y
#VGA Controllers
echo Current VGA controllers:
echo "$(lspci -vnn | grep VGA)"

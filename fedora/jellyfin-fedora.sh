#!/bin/bash
# Repo
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
# Codecs
sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel
sudo dnf install -y lame\* --exclude=lame-devel
sudo dnf group -y upgrade --with-optional Multimedia
# Jellyfin
sudo dnf install -y jellyfin
# System + Firewall
sudo systemctl start jellyfin
sudo systemctl enable jellyfin
sudo firewall-cmd --permanent --add-service=jellyfin
sudo systemctl reboot
#!/bin/bash

# Install homebrew first
brew install \
git \
gh \
htop \
bmon \
btop \
neofetch \
curl \
speedtest-cli \
rclone \
pandoc \
tailscale \
node
echo "| CLI Basics Complete |"

# Casks
brew install --cask \
iterm2 \
arc \
firefox \
google-chrome \
brave-browser \
cyberduck \
remote-desktop-manager-free \
visual-studio-code 

echo "| Cask Basics Complete |"

#termius \
#element \
#carbon-copy-cloner \
#firefox \
#utm \
#obsidian

# MAS
#mas - https://github.com/mas-cli/mas
brew install mas

# Apps

# RunCat
mas install 1429033973
brew install --cask runcat-plugins-manager
# Tailscale
mas install 1475387142
# Magnet
#mas install 441258766
# Todoist
#mas install 585829637
# NordVPN
mas install 905953485
# Blackmagic Disk Speed Test
mas install 425264550
# Apollo - Broken
#mas install 979274575
# Pixelmator Pro
mas install 1289583905
# Graphic
mas install 404705039
# DaisyDisk
mas install 411643860
# Infuse • Video Player
mas install 1136220934

echo "| App Store Basics Complete |"

# Others

# Parallels Desktop 
#mas install 1085114709
# Termius - SSH & SFTP client
#mas install 1176074088  
# FileZilla Pro - Not purchased
#mas install 1298486723
# DaVinci Resolve
#mas install 571213070
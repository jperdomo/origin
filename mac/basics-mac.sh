#!/bin/bash

# Homebrew Update & Upgrade
brew update && brew upgrade

# Homebrew CLI
brew install \
git \
gh \
watch \
stress \
htop \
bmon \
btop \
fastfetch \
curl \
iperf \
nvtop

echo "
| Homebrew CLI Complete |
"

# Homebrew Casks
brew install --cask \
monitorcontrol \
elgato-stream-deck \
remote-desktop-manager \
utm \
cyberduck \
webstorm


echo "
| Homebrew Casks Complete |
"

# Brave Browser
brew install --cask brave-browser

echo "
| Brave Browser Complete |
"
# MAS - https://github.com/mas-cli/mas
brew install mas
# RunCat
mas install 1429033973
#brew install --cask runcat-plugins-manager
# Tailscale
mas install 1475387142
# Magnet
mas install 441258766
# NordVPN
mas install 905953485
# Blackmagic Disk Speed Test
mas install 425264550
# Pixelmator Pro
mas install 1289583905
# Graphic
mas install 404705039
# DaisyDisk
mas install 411643860
# TickTick
mas install 966085870
# Watt - Displays Wattage
mas install 1642732100

echo "
| App Store Basics Complete |
"


# Homebrew Archive
#iterm2 \
#arc \
#termius \
#element \
#carbon-copy-cloner \
#obsidian
#vmware-fusion
#firefox \
#google-chrome \
#visual-studio-code \
#zen-browser \
#brew install --cask eqmac

# MAS Archive
# Infuse • Video Player
#mas install 1136220934
# Todoist
#mas install 585829637
# Apollo - Broken
#mas install 979274575
# Parallels Desktop 
#mas install 1085114709
# Termius - SSH & SFTP client
#mas install 1176074088  
# FileZilla Pro - Not purchased
#mas install 1298486723
# DaVinci Resolve
#mas install 571213070
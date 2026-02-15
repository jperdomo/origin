#!/bin/bash
set -e

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
nvtop \
zed

echo "
| Homebrew CLI Complete |
"

# Homebrew Casks
brew install --cask \
elgato-stream-deck \
remote-desktop-manager \
cyberduck


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
# Watt - Displays Wattage
mas install 1642732100

echo "
| App Store Basics Complete |
"

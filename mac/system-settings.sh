#!/bin/bash

defaults write com.apple.screencapture location ~/Downloads
defaults write com.apple.dock "autohide" -bool "true" && killall Dock
defaults write com.apple.finder "ShowPathbar" -bool "true" && killall Finder
defaults write com.apple.finder "FXDefaultSearchScope" -string "SCcf" && killall Finder
defaults write com.apple.universalaccess "showWindowTitlebarIcons" -bool "true" && killall Finder
#!/bin/bash

# Pipewire
systemctl --user stop pipewire.socket
systemctl --user stop pipewire.service
systemctl --user disable pipewire.socket
systemctl --user disable pipewire.service
systemctl --user mask pipewire
systemctl --user mask pipewire.socket

# PulseAudio
sudo apt install pulseaudio

# User PulseAudio configuration
systemctl --user unmask pulseaudio
systemctl --user unmask pulseaudio.socket
systemctl --user start pulseaudio.service
systemctl --user enable pulseaudio.service

# Verify that pulseaudio is running
echo 'Verifying if pulseaudio is running...'
pactl info

# Reboot the system
echo 'Reboot the system to complete the installation.'
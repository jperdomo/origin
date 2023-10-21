#!/bin/bash

# Set the desired background color (#333333)
color="#333333"

# Set the background color using gsettings
gsettings set org.gnome.desktop.background primary-color "$color"

# Set the background mode to "solid" (to ensure a solid color background)
gsettings set org.gnome.desktop.background picture-options "none"

# Set the background mode to "none" (to ensure no wallpaper is used)
gsettings set org.gnome.desktop.background picture-uri ''

# To refresh the desktop to see the changes immediately, you can use the following command:
# nautilus -q

echo "Background color changed to $color"
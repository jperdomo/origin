#!/bin/bash

##### Broken #####
# Install gnome-extensions-app if not already installed
if ! command -v gnome-extensions-app &> /dev/null; then
    sudo apt update
    sudo apt install gnome-shell-extensions -y
fi

# Install dash to panel extension
#gnome-extensions install dash-to-panel@jderose9.github.com
# Install runcat extension
#gnome-extensions install runcat@dracula-at-night.com
# Install forge extension
#gnome-extensions install forge@peppercarrot.com

# Enable the installed extensions
#gnome-extensions enable runcat@dracula-at-night.com
#gnome-extensions enable forge@peppercarrot.com
#gnome-extensions enable dash-to-panel@jderose9.github.com

#echo "Gnome extensions installed and enabled successfully."



# Broken

# Check if gnome-extensions command is available
if ! [ -x "$(command -v gnome-extensions)" ]; then
  echo "Error: gnome-extensions command not found. Make sure you have the GNOME Shell Extensions package installed."
  exit 1
fi

# UUIDs of the extensions
runcat="run-cat@spoonless.github.io"
dash_to_panel="dash-to-panel@jderose9.github.com"
user_at_host="user-at-host@cmm.github.com"

# RunCat
gnome-extensions install "$runcat"
gnome-extensions enable "$runcat"

# Dash to Panel
gnome-extensions install "$dash_to_panel"
gnome-extensions enable "$dash_to_panel"

# User @ Host
gnome-extensions install "$user_at_host"
gnome-extensions enable "$user_at_host"

echo "RunCat, Dash to Panel, & User @ Host GNOME extensions installed and enabled."

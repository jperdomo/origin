#!/bin/bash

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

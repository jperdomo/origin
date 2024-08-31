#!/bin/bash

COLOR='$22222'

gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background picture-uri-dark ''

gsettings set org.gnome.desktop.background primary-color $COLOR
gsettings set org.gnome.desktop.background secondary-color $COLOR

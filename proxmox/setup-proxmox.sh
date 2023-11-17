#!/bin/bash

# Repos
echo "deb http://download.proxmox.com/debian bookworm pve-no-subscription" >> /etc/apt/sources.list
echo "#deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list

# Update & Upgrade
apt update -y && apt upgrade -y

# Dark Mode
#bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install

# Remove Banner
#sudo sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service

# Done
echo "
Proxmox setup script done
"
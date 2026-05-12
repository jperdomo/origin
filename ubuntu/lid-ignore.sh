#!/bin/bash
set -e

# Run laptop as a server with the lid closed (Ubuntu + GNOME).
# Run this script as the desktop user — it will sudo where needed.
# - Lid closed on AC  → stays awake (gsettings)
# - Lid closed on battery → suspends (default, preserves "in a bag" safety)
# - logind.conf.d snippet keeps lid ignored even at gdm greeter / outside GNOME session
# - Caffeine extension is complementary: it toggles idle/screensaver inhibition

if [ "$EUID" -eq 0 ]; then
    echo "Run as your desktop user, not root. The script will sudo where needed."
    exit 1
fi

# 1. GNOME-level lid action
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'suspend'

echo "gsettings lid-close-ac-action      = $(gsettings get org.gnome.settings-daemon.plugins.power lid-close-ac-action)"
echo "gsettings lid-close-battery-action = $(gsettings get org.gnome.settings-daemon.plugins.power lid-close-battery-action)"

# 2. systemd-logind belt-and-suspenders (covers gdm greeter, tty-only login)
sudo mkdir -p /etc/systemd/logind.conf.d/
sudo tee /etc/systemd/logind.conf.d/99-server-mode.conf > /dev/null <<EOF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl restart systemd-logind

# 3. Caffeine extension (idle/screensaver inhibition toggle in top bar)
# Skip if already present (e.g. installed via the Extensions app / extensions.gnome.org).
# Ubuntu 26.04 dropped the apt package — install manually from the Extensions app if missing.
if gnome-extensions info caffeine@patapon.info >/dev/null 2>&1; then
    gnome-extensions enable caffeine@patapon.info || true
    echo "Caffeine already installed — ensured enabled."
elif apt-cache show gnome-shell-extension-caffeine >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y gnome-shell-extension-caffeine
    gnome-extensions enable caffeine@patapon.info || true
else
    echo "Caffeine not installed and no apt package on this release."
    echo "Install via the Extensions app or https://extensions.gnome.org/extension/517/caffeine/"
fi

echo "Done. Test: plug in AC, close lid, SSH in from another machine — session should stay up."

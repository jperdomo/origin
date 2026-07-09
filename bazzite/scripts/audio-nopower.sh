#!/bin/bash
# Fix HDMI/DP audio pop/crackle on AMD GPUs
# The HDA codec powers down between sounds and pops on wake and on sleep.
# Disabling power saving keeps the codec always on.

set -e

CONF=/etc/modprobe.d/audio-nopower.conf

echo "Writing $CONF..."
sudo tee "$CONF" >/dev/null <<'EOF'
options snd_hda_intel power_save=0 power_save_controller=N
EOF

echo ""
echo "Done! Now:"
echo "  1. Reboot: systemctl reboot"
echo "  2. After reboot, confirm it reads 0:"
echo "     cat /sys/module/snd_hda_intel/parameters/power_save"
echo ""
echo "/etc is writable and persistent on Bazzite, so this survives rpm-ostree upgrades."

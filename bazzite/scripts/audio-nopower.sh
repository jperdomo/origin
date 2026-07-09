#!/bin/bash
# Fix the HDMI/DP audio pop that precedes every sound, on AMD GPUs
# The HDA codec powers down between sounds and pops when it wakes.
# Disabling power saving keeps the codec always on.
#
# This does not fix a trailing pop a beat after sound stops. That one is the
# monitor muting its own amp once it has seen enough digital silence, and no
# host-side setting reaches it. Verified on an RX 9070 XT: with power_save=0
# the codec stays in D0 and the HDMI PCM keeps running, yet the pop remains.

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

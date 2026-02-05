#!/bin/bash
# Fix NetworkManager-tui conflict for Bazzite updates
# The package is now included in the base image, so we remove the layered version

set -e

echo "Removing layered NetworkManager-tui package..."
rpm-ostree uninstall NetworkManager-tui

echo ""
echo "Done! Now:"
echo "  1. Reboot: systemctl reboot"
echo "  2. After reboot, upgrade: rpm-ostree upgrade"
echo "  3. Reboot again to apply the upgrade"
echo ""
echo "nmtui will still work - it's now in the base image."

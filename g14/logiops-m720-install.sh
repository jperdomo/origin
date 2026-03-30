#!/bin/bash
set -e

# Config — find your values with: sudo logid -v
DEVICE_NAME="M720 Triathlon Multi-Device Mouse"
GESTURE_CID="0xd0"

# Install logiops (Logitech HID++ daemon with gesture support)
sudo dnf install -y logiops

# Back up existing config
[ -f /etc/logid.cfg ] && sudo cp /etc/logid.cfg /etc/logid.cfg.bak

# Write logiops config for M720 Triathlon
# Gesture button (top thumb) = tap for Overview, hold+drag for workspace switch
#
# If the device isn't detected, check the name with: sudo logid -v
# and update the "name" field below. CID may also differ — logid -v shows available CIDs.
sudo tee /etc/logid.cfg > /dev/null << EOF
devices: (
{
    name: "${DEVICE_NAME}";
    buttons: (
        {
            cid: ${GESTURE_CID};
            action: {
                type: "Gestures";
                gestures: (
                    {
                        direction: "None";
                        mode: "OnRelease";
                        action: {
                            type: "Keypress";
                            keys: ["KEY_LEFTMETA"];
                        }
                    },
                    {
                        direction: "Left";
                        mode: "OnRelease";
                        action: {
                            type: "Keypress";
                            keys: ["KEY_LEFTCTRL", "KEY_LEFTALT", "KEY_LEFT"];
                        }
                    },
                    {
                        direction: "Right";
                        mode: "OnRelease";
                        action: {
                            type: "Keypress";
                            keys: ["KEY_LEFTCTRL", "KEY_LEFTALT", "KEY_RIGHT"];
                        }
                    }
                );
            }
        }
    );
}
);
EOF

# Enable and (re)start the logid service
sudo systemctl enable logid
sudo systemctl restart logid

echo ""
echo "logiops configured for M720 Triathlon."
echo "  Gesture button tap        → Activities Overview"
echo "  Gesture button + drag L/R → Switch workspace"
echo ""
echo "Logs: sudo journalctl -u logid -f"
echo "Edit: /etc/logid.cfg  (restart: sudo systemctl restart logid)"

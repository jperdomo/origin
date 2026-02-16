#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZED_CONFIG_DIR="$HOME/.config/zed"

mkdir -p "$ZED_CONFIG_DIR"

# Symlink settings.json
if [ -f "$ZED_CONFIG_DIR/settings.json" ] && [ ! -L "$ZED_CONFIG_DIR/settings.json" ]; then
    echo "Backing up existing settings.json to settings.json.bak"
    mv "$ZED_CONFIG_DIR/settings.json" "$ZED_CONFIG_DIR/settings.json.bak"
fi

ln -sf "$SCRIPT_DIR/settings.json" "$ZED_CONFIG_DIR/settings.json"
echo "Linked settings.json -> $ZED_CONFIG_DIR/settings.json"

echo ""
echo "NOTE: Install required extensions manually in Zed (Cmd+Shift+X):"
echo "  - GitHub Theme"

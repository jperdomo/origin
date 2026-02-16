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

# Auto-push: watch for settings changes and commit/push
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.zed-autopush.plist"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.zed-autopush</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd "$REPO_DIR" &amp;&amp; /usr/bin/git add zed/ &amp;&amp; /usr/bin/git diff --cached --quiet || (cd "$REPO_DIR" &amp;&amp; /usr/bin/git commit -m "Auto-update Zed settings" &amp;&amp; /usr/bin/git push)</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$REPO_DIR/zed/settings.json</string>
    </array>
    <key>StandardOutPath</key>
    <string>/tmp/zed-autopush.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/zed-autopush.error.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Zed auto-push enabled (watches for settings changes)."
echo "Logs: /tmp/zed-autopush.log"

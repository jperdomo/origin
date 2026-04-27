#!/bin/bash
set -e

# VS Code via official Microsoft APT repo (best native integration on Ubuntu
# 26 LTS — flatpak's sandbox breaks host terminals, docker, and native
# toolchains that a dev IDE needs)
sudo apt update
sudo apt install -y wget gpg apt-transport-https jq

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg

sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'SOURCES'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/packages.microsoft.gpg
SOURCES

sudo apt update
sudo apt install -y code

# Claude Code IDE integration. Pairs with the CLI from claude-install.sh —
# launching `claude` inside the integrated terminal would auto-install this,
# but pre-seeding means the extension is already there on first launch.
code --install-extension anthropic.claude-code --force

# Strip Copilot. Recent VS Code builds ship Copilot + Copilot Chat as bundled
# extensions and the chat view is what surfaces the Agent sidebar; removing
# the extensions takes the sidebar with them. Uninstall is idempotent — if
# the extension isn't present, fall through silently.
code --uninstall-extension github.copilot --force 2>/dev/null || true
code --uninstall-extension github.copilot-chat --force 2>/dev/null || true

# User settings pre-seed. VS Code on Linux has no Chromium-style managed
# policy system, so we write to settings.json. Covers privacy (telemetry +
# online services) and UX defaults (theme, no welcome page, no walkthroughs,
# no chat title-bar widget in case Copilot Chat sneaks back via update).
SETTINGS_DIR="$HOME/.config/Code/User"
SETTINGS="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

OVERRIDES='{
  "telemetry.telemetryLevel": "off",
  "workbench.enableExperiments": false,
  "workbench.settings.enableNaturalLanguageSearch": false,
  "npm.fetchOnlinePackageInfo": false,
  "typescript.surveys.enabled": false,
  "workbench.colorTheme": "Dark 2026",
  "workbench.startupEditor": "none",
  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "workbench.welcomePage.experimentalOnboarding": false,
  "chat.disableAIFeatures": true,
  "chat.commandCenter.enabled": false
}'

if [ -s "$SETTINGS" ]; then
  tmp=$(mktemp)
  jq --argjson o "$OVERRIDES" '. * $o' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
else
  echo "$OVERRIDES" > "$SETTINGS"
fi

# argv.json controls runtime flags read before settings.json loads. Disabling
# the crash reporter here belt-and-braces with telemetryLevel=off.
ARGV_DIR="$HOME/.vscode"
ARGV="$ARGV_DIR/argv.json"
mkdir -p "$ARGV_DIR"

ARGV_OVERRIDES='{
  "enable-crash-reporter": false
}'

if [ -s "$ARGV" ]; then
  tmp=$(mktemp)
  jq --argjson o "$ARGV_OVERRIDES" '. * $o' "$ARGV" > "$tmp" && mv "$tmp" "$ARGV"
else
  echo "$ARGV_OVERRIDES" > "$ARGV"
fi

echo "VS Code installed. Launch with 'code'."

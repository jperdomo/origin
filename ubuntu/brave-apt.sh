#!/bin/bash
set -e

# Brave via official APT repo (best native integration on Ubuntu 26 LTS)
sudo apt update
sudo apt install -y curl jq

sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

sudo apt update
sudo apt install -y brave-browser

# Default browser. xdg-settings alone isn't enough — terminals and other apps
# call xdg-open, which dispatches via MIME handlers in mimeapps.list. Set both.
xdg-settings set default-web-browser brave-browser.desktop
for mime in \
    x-scheme-handler/http \
    x-scheme-handler/https \
    x-scheme-handler/about \
    x-scheme-handler/unknown \
    text/html; do
    xdg-mime default brave-browser.desktop "$mime"
done

# System-wide policies: kill Rewards/News/Talk entirely and force DuckDuckGo as
# the default search. Policy-managed settings appear as "Managed by your
# organization" in the UI and can't be toggled there — that's the trade-off for
# install-time configuration that survives profile resets.
sudo mkdir -p /etc/brave/policies/managed
sudo tee /etc/brave/policies/managed/setup.json >/dev/null <<'JSON'
{
  "BraveRewardsDisabled": true,
  "BraveNewsDisabled": true,
  "BraveTalkDisabled": true,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderKeyword": ":d",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://duckduckgo.com/ac/?q={searchTerms}&type=list",
  "DefaultSearchProviderIconURL": "https://duckduckgo.com/favicon.ico",
  "ExtensionSettings": {
    "nngceckbapebfimnlniiiahkandclblb": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx",
      "toolbar_pin": "force_pinned"
    }
  }
}
JSON

# NTP widget toggles (clock on, stats off, sponsored backgrounds off) live in
# the user Preferences file — there's no managed-policy equivalent. Pre-seed
# them so they take effect on first launch; merge if the file already exists.
PROFILE_DIR="$HOME/.config/BraveSoftware/Brave-Browser/Default"
PREFS="$PROFILE_DIR/Preferences"
mkdir -p "$PROFILE_DIR"

OVERRIDES='{
  "brave": {
    "new_tab_page": {
      "show_clock": true,
      "show_stats": false,
      "show_background_image": true,
      "show_branded_background_image": false
    }
  }
}'

if [ -s "$PREFS" ]; then
  tmp=$(mktemp)
  jq --argjson o "$OVERRIDES" '. * $o' "$PREFS" > "$tmp" && mv "$tmp" "$PREFS"
else
  echo "$OVERRIDES" > "$PREFS"
fi

echo "Brave installed and configured. Launch with 'brave-browser'."

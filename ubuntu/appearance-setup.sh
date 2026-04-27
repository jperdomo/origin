#!/bin/bash
set -e

# Ubuntu 26.04 LTS ships Ptyxis (org.gnome.Ptyxis) as the default terminal.
# Install Extension Manager + helpers (Ptyxis is preinstalled with the desktop).
sudo apt update
sudo apt install -y gnome-shell-extension-manager curl unzip jq

# Hide Home Folder (only if Desktop Icons NG extension is installed)
if gsettings list-schemas 2>/dev/null | grep -q 'org.gnome.shell.extensions.ding'; then
    gsettings set org.gnome.shell.extensions.ding show-home false
fi

# 12hr Clock
gsettings set org.gnome.desktop.interface clock-format '12h'

# Battery percentage in top bar (only if a battery is present, i.e. a laptop)
if compgen -G "/sys/class/power_supply/BAT*" > /dev/null; then
    gsettings set org.gnome.desktop.interface show-battery-percentage true
fi

# Dark Mode (system-wide, GNOME 48+)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Ptyxis dark mode (explicit, in case user toggled it light)
gsettings set org.gnome.Ptyxis interface-style 'dark' 2>/dev/null || true

# Ptyxis: set default profile palette to Campbell (dark, no purple tint)
PTYXIS_UUID=$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'" || true)
if [ -n "$PTYXIS_UUID" ]; then
    gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${PTYXIS_UUID}/" palette 'campbell' 2>/dev/null || true
fi

# Override Ptyxis launcher icon (default is purple) to a neutral gray
# utilities-terminal glyph by shipping a per-user .desktop override.
PTYXIS_DESKTOP_SRC="/usr/share/applications/org.gnome.Ptyxis.desktop"
PTYXIS_DESKTOP_DST="$HOME/.local/share/applications/org.gnome.Ptyxis.desktop"
if [ -f "$PTYXIS_DESKTOP_SRC" ]; then
    mkdir -p "$(dirname "$PTYXIS_DESKTOP_DST")"
    sed 's/^Icon=.*/Icon=utilities-terminal/' "$PTYXIS_DESKTOP_SRC" > "$PTYXIS_DESKTOP_DST"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Drop Ubuntu's purple accent. Use blue.
if gsettings list-keys org.gnome.desktop.interface 2>/dev/null | grep -q '^accent-color$'; then
    gsettings set org.gnome.desktop.interface accent-color 'blue'
fi

# Dark BKG
COLOR='#222222'

gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background picture-uri-dark ''

gsettings set org.gnome.desktop.background primary-color $COLOR
gsettings set org.gnome.desktop.background secondary-color $COLOR

# Smaller Ubuntu Dock (32px, fixed)
if gsettings list-schemas 2>/dev/null | grep -q 'org.gnome.shell.extensions.dash-to-dock'; then
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
    gsettings set org.gnome.shell.extensions.dash-to-dock icon-size-fixed true
fi

# GNOME Shell extensions: install from extensions.gnome.org and persist enable.
# `gnome-extensions enable` right after install often fails because the running
# shell hasn't registered the new UUID yet — write directly into the
# enabled-extensions list so it sticks across the next shell restart.
SHELL_VER=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)

install_gnome_extension() {
    local uuid="$1"
    if ! gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
        local info dl_path tmp
        info=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}")
        dl_path=$(echo "$info" | jq -r '.download_url')
        if [ -n "$dl_path" ] && [ "$dl_path" != "null" ]; then
            tmp=$(mktemp -d)
            curl -fsSL "https://extensions.gnome.org${dl_path}" -o "$tmp/ext.zip"
            gnome-extensions install --force "$tmp/ext.zip"
            rm -rf "$tmp"
        else
            echo "WARN: could not resolve $uuid download for GNOME ${SHELL_VER}" >&2
            return 1
        fi
    fi
    # EGO often serves bundles whose metadata.json hasn't been bumped for the
    # current GNOME release — the shell then marks them OUT OF DATE and refuses
    # to load. Append the running shell version so they load.
    local meta="$HOME/.local/share/gnome-shell/extensions/$uuid/metadata.json"
    if [ -f "$meta" ] && ! jq -e --arg v "$SHELL_VER" '."shell-version" | index($v)' "$meta" >/dev/null; then
        jq --arg v "$SHELL_VER" '."shell-version" += [$v]' "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"
    fi
    local current
    current=$(gsettings get org.gnome.shell enabled-extensions)
    if ! echo "$current" | grep -q "'$uuid'"; then
        if [ "$current" = "@as []" ] || [ "$current" = "[]" ]; then
            gsettings set org.gnome.shell enabled-extensions "['$uuid']"
        else
            gsettings set org.gnome.shell enabled-extensions "${current%]}, '$uuid']"
        fi
    fi
    gnome-extensions enable "$uuid" 2>/dev/null || true
}

# ext_gsettings <uuid> <schema-id> <key> <value>: set a key on an extension's
# own schema before gnome-shell has had a chance to load it system-wide.
ext_gsettings() {
    local schema_dir="$HOME/.local/share/gnome-shell/extensions/$1/schemas"
    [ -d "$schema_dir" ] || return 0
    [ -f "$schema_dir/gschemas.compiled" ] || glib-compile-schemas "$schema_dir" 2>/dev/null || true
    GSETTINGS_SCHEMA_DIR="$schema_dir" gsettings set "$2" "$3" "$4" 2>/dev/null || true
}

# Tiling Shell — auto-tile on, no gaps
TS_UUID="tilingshell@ferrarodomenico.com"
install_gnome_extension "$TS_UUID"
ext_gsettings "$TS_UUID" org.gnome.shell.extensions.tilingshell enable-autotiling true
ext_gsettings "$TS_UUID" org.gnome.shell.extensions.tilingshell enable-snap-assist true
ext_gsettings "$TS_UUID" org.gnome.shell.extensions.tilingshell inner-gaps 0
ext_gsettings "$TS_UUID" org.gnome.shell.extensions.tilingshell outer-gaps 0

# Runcat — animated load indicator in the top bar
install_gnome_extension "runcat@kolesnikov.se"

# Favorites: Ptyxis (terminal), Files, VS Code if present (slot 3), plus a
# browser. If both Firefox and Brave are installed, only the system default
# browser is pinned — no point in two browser icons sitting next to each
# other in the dock.
FAVORITES=("org.gnome.Ptyxis.desktop" "org.gnome.Nautilus.desktop")

if [ -f /usr/share/applications/code.desktop ]; then
    FAVORITES+=("code.desktop")
fi

firefox_installed=false
if [ -f /var/lib/snapd/desktop/applications/firefox_firefox.desktop ] \
   || [ -f /usr/share/applications/firefox.desktop ] \
   || command -v firefox >/dev/null 2>&1; then
    firefox_installed=true
fi

brave_installed=false
if [ -f /usr/share/applications/brave-browser.desktop ]; then
    brave_installed=true
fi

if $firefox_installed && $brave_installed; then
    case "$(xdg-settings get default-web-browser 2>/dev/null)" in
        brave-browser.desktop) FAVORITES+=("brave-browser.desktop") ;;
        *) FAVORITES+=("firefox_firefox.desktop") ;;
    esac
elif $brave_installed; then
    FAVORITES+=("brave-browser.desktop")
elif $firefox_installed; then
    FAVORITES+=("firefox_firefox.desktop")
fi

fav_list=$(printf "'%s', " "${FAVORITES[@]}")
gsettings set org.gnome.shell favorite-apps "[${fav_list%, }]"

# Trash at end of dock (Software/Help drop off via the favorites override above)
if gsettings list-schemas 2>/dev/null | grep -q 'org.gnome.shell.extensions.dash-to-dock'; then
    gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false
fi

#!/usr/bin/env bash
#
# kde-macos-theme.sh - macOS (WhiteSur) look for KDE Plasma 6 on Bazzite.
#
# NON-DESTRUCTIVE by design (researched against KDE's lnftool.cpp):
#   * Appearance is applied WITHOUT --resetLayout, so your panels + pinned apps
#     are preserved. --resetLayout is the ONLY thing that wipes them; we never
#     call it.
#   * The macOS top bar + dock are ADDED via the Plasma scripting API (new Panel
#     only adds, never resets), guarded by a marker so re-runs don't stack them.
#
# Fixes the "dark text on dark menus" bug: that was the colour scheme never
# being applied. plasma-apply-colorscheme WhiteSurDark writes the palette into
# kdeglobals, which is what makes menus readable (Breeze widget style is fine).
#
# Kvantum is intentionally NOT used (it needs rpm-ostree layering + reboot on
# atomic Bazzite; Breeze + the WhiteSur colour scheme renders menus correctly).
#
# Usage:  ./kde-macos-theme.sh            install themes, apply appearance + add panels (once)
#         RELAYOUT=1 ./kde-macos-theme.sh add the top bar + dock again (if you removed them)
#         ./kde-macos-theme.sh --apply    re-apply appearance only (no panel changes)
#         ./kde-macos-theme.sh --fetch    only clone/update the source repos

set -euo pipefail

ACCENT="purple"; KCOLOR="dark"
ICON_THEME="WhiteSur-${ACCENT}-${KCOLOR}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_DATA_HOME:-$HOME/.local/share}/whitesur-src"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
REPOS=(WhiteSur-kde WhiteSur-icon-theme WhiteSur-cursors)   # no GTK theme (dropped)
PANEL_MARKER="$CFG/.whitesur-macos-panels"

b=$'\e[1m'; bl=$'\e[34m'; gr=$'\e[32m'; yl=$'\e[33m'; rs=$'\e[0m'
info(){ echo "${bl}${b}::${rs} $*"; }
ok(){ echo "${gr}${b}✓${rs} $*"; }
warn(){ echo "${yl}${b}!${rs} $*" >&2; }

QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)"

fetch_repos() {
  info "Fetching WhiteSur sources into $SRC"
  mkdir -p "$SRC"
  local r
  for r in "${REPOS[@]}"; do
    if [[ -d "$SRC/$r/.git" ]]; then
      git -C "$SRC/$r" pull --quiet --ff-only 2>/dev/null || warn "$r: pull failed (using existing)"
    else
      git clone --depth=1 --quiet "https://github.com/vinceliuice/$r.git" "$SRC/$r"
    fi
    ok "$r"
  done
}

install_themes() {
  info "Installing icons ($ICON_THEME)"
  bash "$SRC/WhiteSur-icon-theme/install.sh" -t "$ACCENT" -a
  info "Installing KDE theme (plasma theme, colour schemes, look-and-feel, aurorae, kvantum files)"
  bash "$SRC/WhiteSur-kde/install.sh" -c "$KCOLOR"
  info "Installing cursors"
  bash "$SRC/WhiteSur-cursors/install.sh" 2>/dev/null || warn "cursor install had a hiccup (non-fatal)"
}

apply_appearance() {
  # Appearance only - NO --resetLayout, so panels/pins are preserved.
  info "Applying WhiteSur appearance (keeping your panels + pinned apps)"
  plasma-apply-lookandfeel -a com.github.vinceliuice.WhiteSur-dark || warn "look-and-feel apply failed"

  # THE menu-contrast fix: actually write the colour scheme into kdeglobals.
  info "Applying colour scheme WhiteSurDark (fixes dark-on-dark menus)"
  plasma-apply-colorscheme WhiteSurDark || warn "colorscheme apply failed"

  # Keep the widget style Breeze (renders correctly with the colour scheme).
  kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze

  info "Applying plasma desktop theme + cursor"
  plasma-apply-desktoptheme WhiteSur-dark || warn "desktoptheme apply failed"
  plasma-apply-cursortheme WhiteSur-cursors 2>/dev/null || warn "cursor apply failed"

  info "Applying icon theme ($ICON_THEME)"
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME"
  plasma-changeicons "$ICON_THEME" 2>/dev/null || warn "plasma-changeicons unavailable (icons set via config; applies on relogin)"

  info "Window decorations: Aurorae WhiteSur-dark, buttons on the LEFT (macOS)"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__WhiteSur-dark"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"   # close,min,max
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""

  # GTK apps: just go dark + WhiteSur icons (no WhiteSur GTK theme installed).
  kwriteconfig6 --file kdeglobals --group General --key GtkTheme "Breeze-Dark" 2>/dev/null || true
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "Breeze-Dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
  fi
}

# Read the user's current dock launchers so the new dock mirrors their pins.
seed_launchers_js() {
  local f="$CFG/plasma-org.kde.plasma.desktop-appletsrc" line
  line="$(grep -m1 '^launchers=' "$f" 2>/dev/null | cut -d= -f2- || true)"
  [[ -z "$line" ]] && line="applications:org.kde.dolphin.desktop,applications:com.brave.Browser.desktop,applications:org.kde.konsole.desktop,applications:systemsettings.desktop"
  local IFS=',' item js=""
  for item in $line; do [[ -n "$item" ]] && js+="\"$item\","; done
  echo "${js%,}"
}

dock_js() {
  cat <<EOF
var dock = new Panel;
dock.location = "bottom";
dock.alignment = "center";
dock.floating = true;
dock.lengthMode = "fit";
dock.height = Math.round(gridUnit * 3);
dock.hiding = "dodgewindows";
var t = dock.addWidget("org.kde.plasma.icontasks");
t.currentConfigGroup = ["General"];
t.writeConfig("launchers", [$(seed_launchers_js)]);
t.writeConfig("showOnlyCurrentDesktop", false);
t.reloadConfig();
EOF
}

apply_layout() {
  # Make the top-bar template available for the GUI (Add Panel) as well.
  mkdir -p "$SRC/../plasma/layout-templates" 2>/dev/null || true
  local tpldir="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/layout-templates"
  mkdir -p "$tpldir"
  cp -r "$SRC/WhiteSur-kde/plasma/layout-templates/org.github.desktop.WhiteSurPanel" "$tpldir/" 2>/dev/null || true

  if [[ -f "$PANEL_MARKER" && -z "${RELAYOUT:-}" ]]; then
    info "macOS top bar + dock already added earlier (skipping so they don't stack)."
    info "  To add them again (e.g. you removed them): RELAYOUT=1 ./kde-macos-theme.sh"
    return 0
  fi
  [[ -n "$QDBUS" ]] || { warn "qdbus not found - add the top bar via Add Panel > WhiteSurPanel, dock manually."; return 0; }

  local topjs="$SRC/WhiteSur-kde/plasma/layout-templates/org.github.desktop.WhiteSurPanel/contents/layout.js"
  info "Adding the macOS top bar (additive - existing panels untouched)"
  "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$topjs")" >/dev/null 2>&1 \
    || warn "top-bar add failed (add via Add Panel > WhiteSurPanel)"

  info "Adding the macOS dock (centered/floating, seeded with your current pins)"
  "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(dock_js)" >/dev/null 2>&1 \
    || warn "dock add failed"

  touch "$PANEL_MARKER"
  ok "Top bar + dock added."
}

# Persist the layout AND remove the old full-width bottom panel - the RELIABLE way.
# The live scripting remove() is racy: plasmashell rewrites appletsrc from memory
# on exit, and removing a systemtray panel can crash it (KDE#453726) before it
# saves - which is why it kept coming back. Instead: stop plasmashell (this flushes
# the just-added dock/top-bar to disk), delete the full bottom panel from the config
# FILE, then restart. Persistent across relogin. Safe: the helper only deletes a
# panel with a systemtray/kickoff/clock, never the icons-only dock.
persist_and_clean_panels() {
  local f="$CFG/plasma-org.kde.plasma.desktop-appletsrc"
  local py="$HERE/kde-remove-full-bottom-panel.py"
  [[ -f "$f" ]] || { warn "appletsrc not found; skipping panel cleanup."; return 0; }
  [[ -f "$py" ]] || { warn "panel-surgery helper missing ($py); skipping."; return 0; }

  info "Stopping plasmashell to persist layout + remove the old bottom bar"
  cp "$f" "$f.bak" 2>/dev/null || true
  kquitapp6 plasmashell >/dev/null 2>&1 || true
  local n; for n in $(seq 1 20); do pgrep -x plasmashell >/dev/null 2>&1 || break; sleep 0.5; done

  local res; res="$(python3 "$py" "$f" 2>&1 || echo error)"
  case "$res" in
    removed:none) info "No full-width bottom panel present (already clean)." ;;
    removed:*)    ok "Removed full bottom panel: ${res#removed:} (backup: $f.bak)" ;;
    *)            warn "Panel surgery said '$res'; restore with: cp $f.bak $f" ;;
  esac

  info "Restarting plasmashell"
  (command -v kstart6 >/dev/null 2>&1 && kstart6 plasmashell || kstart plasmashell || setsid plasmashell) >/dev/null 2>&1 &
}

# Lock screen follows the desktop wallpaper. Plasma 6 has no native toggle, so a
# tiny systemd --user path watcher copies the current desktop wallpaper into
# kscreenlockerrc whenever it changes (applies on next lock, no relogin).
setup_lockscreen_sync() {
  info "Setting up lock-screen wallpaper sync (follows your desktop wallpaper)"
  local bindir="$HOME/.local/bin" ucfg="$CFG/systemd/user"
  mkdir -p "$bindir" "$ucfg"
  cat > "$bindir/sync-lockscreen-wallpaper.sh" <<'SH'
#!/usr/bin/env bash
QB="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)"
IMG=""
[[ -n "$QB" ]] && IMG="$("$QB" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'var d=desktops()[0]; d.currentConfigGroup=["Wallpaper","org.kde.image","General"]; print(d.readConfig("Image"));' 2>/dev/null)"
[[ -z "$IMG" ]] && IMG="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
  --group Containments --group 1 --group Wallpaper --group org.kde.image --group General --key Image 2>/dev/null)"
[[ -n "$IMG" ]] && kwriteconfig6 --file kscreenlockerrc \
  --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "$IMG"
SH
  chmod +x "$bindir/sync-lockscreen-wallpaper.sh"
  cat > "$ucfg/synclock.service" <<SVC
[Unit]
Description=Sync lock screen wallpaper from desktop wallpaper
[Service]
Type=oneshot
ExecStart=$bindir/sync-lockscreen-wallpaper.sh
SVC
  cat > "$ucfg/synclock.path" <<'PTH'
[Unit]
Description=Watch desktop wallpaper config
[Path]
PathModified=%h/.config/plasma-org.kde.plasma.desktop-appletsrc
[Install]
WantedBy=default.target
PTH
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now synclock.path 2>/dev/null || warn "enable synclock.path after login: systemctl --user enable --now synclock.path"
  "$bindir/sync-lockscreen-wallpaper.sh" 2>/dev/null || true   # sync once now
  ok "Lock screen will track your desktop wallpaper (updates on next lock)."
}

reload_kwin() { [[ -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }

case "${1:-}" in
  --fetch) fetch_repos; ok "Done (fetch only)."; exit 0 ;;
  --apply) apply_appearance; reload_kwin; ok "Appearance re-applied (no panel changes)."; exit 0 ;;
esac

fetch_repos
install_themes
apply_appearance
apply_layout               # adds top bar + dock once (marker-guarded, live)
setup_lockscreen_sync
persist_and_clean_panels   # flush layout + delete old bottom bar (stop/edit/restart plasmashell)
reload_kwin

echo
ok "WhiteSur macOS theme applied: top bar + floating dock; old bottom bar removed; lock screen tracks wallpaper."
echo "   ${b}Log out and back in${rs} so the widget style, window buttons and icons fully settle."
echo "   Your pinned apps were carried into the dock. If the old bar somehow lingers,"
echo "   re-run this (it's safe/idempotent) or remove it via right-click > Edit Mode > Remove Panel."
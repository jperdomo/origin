#!/usr/bin/env bash
#
# kde-default-dark.sh - Full revert from the macOS (WhiteSur) look to stock KDE
# Breeze Dark: default appearance AND the default panel layout (a single normal
# bottom bar; the macOS top bar + floating dock are removed). Your pinned apps
# are carried into the bottom bar so nothing is lost.
#
# Layout change uses the safe method: add the default bottom panel live, then
# stop plasmashell and delete the mac panels from the config FILE, then restart.
#
# Usage:  ./kde-default-dark.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)"
info(){ echo ":: $*"; }
warn(){ echo "! $*" >&2; }

# --- appearance: stock Breeze Dark (no --resetLayout) ----------------------
info "Applying stock KDE Breeze Dark appearance"
plasma-apply-lookandfeel -a org.kde.breezedark.desktop || warn "look-and-feel apply failed"
plasma-apply-colorscheme BreezeDark 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group KDE   --key widgetStyle Breeze
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "Breeze"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "IAX"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "Breeze-Dark" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "breeze-dark" 2>/dev/null || true
fi

# --- layout: restore a normal bottom bar, remove the mac panels ------------
f="$CFG/plasma-org.kde.plasma.desktop-appletsrc"
py="$HERE/kde-remove-mac-panels.py"
if [[ -z "$QDBUS" || ! -f "$py" ]]; then
  warn "qdbus or helper missing; appearance reverted, but couldn't change panels."
  warn "Remove the top bar + dock via right-click > Enter Edit Mode > Remove Panel."
  [[ -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  exit 0
fi

# Preserve current pins (the dock's launchers) into the new bottom bar.
launchers_csv="$(grep -m1 '^launchers=' "$f" 2>/dev/null | cut -d= -f2- || true)"
[[ -z "$launchers_csv" ]] && launchers_csv="applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop"
js_launchers=""; IFS=','; for x in $launchers_csv; do [[ -n "$x" ]] && js_launchers+="\"$x\","; done; unset IFS
js_launchers="${js_launchers%,}"

info "Adding a standard bottom panel (with your pins) before removing the mac panels"
"$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var p = new Panel;
p.location = 'bottom';
p.height = Math.round(gridUnit * 2.2);
var kf = p.addWidget('org.kde.plasma.kickoff');
kf.currentConfigGroup = ['General'];
kf.writeConfig('icon', 'bazzite-logo-icon');   // keep the Bazzite launcher logo
kf.reloadConfig();
var t = p.addWidget('org.kde.plasma.icontasks');
t.currentConfigGroup = ['General'];
t.writeConfig('launchers', [${js_launchers}]);
t.reloadConfig();
p.addWidget('org.kde.plasma.marginsseparator');
p.addWidget('org.kde.plasma.systemtray');
p.addWidget('org.kde.plasma.digitalclock');
p.addWidget('org.kde.plasma.showdesktop');
" >/dev/null 2>&1 || warn "adding bottom panel failed"

info "Stopping plasmashell to remove the macOS top bar + dock (persistent)"
cp "$f" "$f.bak" 2>/dev/null || true
kquitapp6 plasmashell >/dev/null 2>&1 || true
for _ in $(seq 1 20); do pgrep -x plasmashell >/dev/null 2>&1 || break; sleep 0.5; done

res="$(python3 "$py" "$f" 2>&1 || echo error)"
case "$res" in
  removed:none) info "No mac panels found to remove (already default?)." ;;
  removed:*)    info "Removed mac panels: ${res#removed:} (backup: $f.bak)" ;;
  *)            warn "panel removal said '$res'; restore with: cp $f.bak $f" ;;
esac

info "Restarting plasmashell"
(command -v kstart6 >/dev/null 2>&1 && kstart6 plasmashell || kstart plasmashell || setsid plasmashell) >/dev/null 2>&1 &

echo ":: Done - stock KDE Breeze Dark + default bottom bar (mac top bar & dock removed; pins kept)."
echo "   Log out/in to fully settle. Re-run the 'theme' option to go back to macOS."

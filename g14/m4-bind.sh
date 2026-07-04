#!/usr/bin/env bash
#
# m4-bind.sh - Bind the G14 "M4" key to open ROG Control Center (KDE Plasma 6).
#
# The M4 key emits KEY_PROG1 (keysym XF86Launch1), which KDE names "Launch (1)".
# We register a global launch shortcut for rog-control-center.desktop in
# kglobalshortcutsrc, then reload kglobalaccel.
#
# Usage:  ./m4-bind.sh            bind M4 -> ROG Control Center
#         ./m4-bind.sh --remove   remove the binding
#         KEYNAME="Launch (1)" ./m4-bind.sh    override the key name if needed

set -euo pipefail

DESKTOP="rog-control-center.desktop"
FRIENDLY="ROG Control Center"
KEYNAME="${KEYNAME:-Launch (1)}"      # KDE's name for XF86Launch1 (the M4 key)
APPFILE="$HOME/.local/share/applications/$DESKTOP"

info() { echo ":: $*"; }
ok()   { echo "✓ $*"; }
warn() { echo "! $*" >&2; }

reload_kglobalaccel() {
  # Make kglobalaccel pick up the edited file. A relogin is the guaranteed way;
  # this tries a live restart first.
  if command -v kquitapp6 >/dev/null 2>&1; then
    kquitapp6 kglobalacceld >/dev/null 2>&1 || true
    if command -v kstart6 >/dev/null 2>&1; then kstart6 kglobalacceld >/dev/null 2>&1 &
    elif command -v kstart >/dev/null 2>&1; then kstart kglobalacceld >/dev/null 2>&1 &
    else setsid kglobalacceld >/dev/null 2>&1 & fi
  fi
}

if [[ "${1:-}" == "--remove" ]]; then
  kwriteconfig6 --file kglobalshortcutsrc --group "$DESKTOP" --key _launch --delete 2>/dev/null || true
  kwriteconfig6 --file kglobalshortcutsrc --group "$DESKTOP" --key _k_friendly_name --delete 2>/dev/null || true
  reload_kglobalaccel
  ok "Removed M4 -> $FRIENDLY binding."
  exit 0
fi

command -v kwriteconfig6 >/dev/null 2>&1 || { warn "kwriteconfig6 not found (KDE Plasma 6 required)."; exit 1; }
[[ -f "$APPFILE" ]] || warn "$DESKTOP not found in ~/.local/share/applications (is ROG Control Center installed?)"

info "Binding M4 (\"$KEYNAME\") -> $FRIENDLY"
# Format: <shortcut>,<default>,<friendly display name>
kwriteconfig6 --file kglobalshortcutsrc --group "$DESKTOP" --key _k_friendly_name "$FRIENDLY"
kwriteconfig6 --file kglobalshortcutsrc --group "$DESKTOP" --key _launch "${KEYNAME},none,${FRIENDLY}"

reload_kglobalaccel
ok "Bound. Press M4 to test."
echo "   If nothing happens, log out and back in (kglobalaccel registers launch"
echo "   shortcuts at login). If M4 uses a different name, re-run with e.g."
echo "   KEYNAME='Launch (1)' ./m4-bind.sh  (we detected KEY_PROG1 / XF86Launch1)."

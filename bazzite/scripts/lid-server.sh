#!/usr/bin/env bash
#
# lid-server.sh - Run the G14 like a server on AC: close the lid and it keeps
# running (KDE Plasma 6 / Bazzite). On battery the lid still suspends, so the
# laptop is safe to carry closed in a bag.
#
#   AC      + lid closed  -> stays awake  (PowerDevil lidAction=0 "do nothing")
#   Battery + lid closed  -> suspends     (PowerDevil lidAction=1, KDE default)
#
# Two layers, because each governs a different moment:
#   1. KDE PowerDevil (powerdevilrc)  - the authority while you're logged into
#      Plasma; it holds the lid inhibitor, so logind defers to it.
#   2. systemd-logind snippet         - belt-and-suspenders for the SDDM
#      greeter / a bare TTY / after logout, when PowerDevil isn't running.
#
# KDE's stock AC profile already does NOT idle-suspend (it only dims / blanks
# the screen), so a lid-open server won't nod off either; we don't touch that.
#
# Run as your desktop user (it sudos only for the logind snippet).
# Usage:  ./lid-server.sh            enable server-on-AC lid behaviour
#         ./lid-server.sh --revert   restore stock (lid suspends on AC again)

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Run as your desktop user, not root (the script sudos where needed)." >&2
  exit 1
fi

LOGIND_SNIPPET=/etc/systemd/logind.conf.d/99-g14-server-lid.conf

# lidAction enum (PowerDevil SuspendSession modes): 0 = do nothing, 1 = sleep.
reload_powerdevil() {
  # PowerDevil watches powerdevilrc and reloads on change; the restart just
  # guarantees it even on older builds. Both are best-effort.
  systemctl --user try-restart plasma-powerdevil.service 2>/dev/null || true
}

if [[ "${1:-}" == "--revert" ]]; then
  kwriteconfig6 --file powerdevilrc --group AC         --group HandleButtonEvents --key lidAction 1
  kwriteconfig6 --file powerdevilrc --group Battery    --group HandleButtonEvents --key lidAction 1
  kwriteconfig6 --file powerdevilrc --group LowBattery --group HandleButtonEvents --key lidAction 1
  reload_powerdevil
  sudo rm -f "$LOGIND_SNIPPET"
  # reload (SIGHUP), NOT restart: restarting logind in a live graphical session
  # tears down the seat and crashes the compositor (login loop). reload re-reads
  # config without touching sessions.
  sudo systemctl reload systemd-logind
  echo "Reverted: closing the lid suspends on AC and on battery (KDE default)."
  exit 0
fi

# --- 1. KDE PowerDevil ------------------------------------------------------
kwriteconfig6 --file powerdevilrc --group AC         --group HandleButtonEvents --key lidAction 0
kwriteconfig6 --file powerdevilrc --group Battery    --group HandleButtonEvents --key lidAction 1
kwriteconfig6 --file powerdevilrc --group LowBattery --group HandleButtonEvents --key lidAction 1
reload_powerdevil

# --- 2. systemd-logind (greeter / TTY / logged-out) -------------------------
sudo mkdir -p "$(dirname "$LOGIND_SNIPPET")"
sudo tee "$LOGIND_SNIPPET" >/dev/null <<'EOF'
[Login]
# G14 server mode: on AC (or docked) a closed lid does not suspend.
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
# On battery the lid still suspends, so it's safe to carry closed.
HandleLidSwitch=suspend
EOF
# reload (SIGHUP), NEVER restart: restarting systemd-logind while logged into
# Plasma/Wayland tears down the seat, crashes the compositor, and bounces you
# into a login loop (only a reboot recovers). reload re-reads logind.conf.d
# without disturbing any active session; the new lid behaviour applies at once.
sudo systemctl reload systemd-logind

echo "Done."
echo "  AC      + lid closed -> stays awake (runs like a server)"
echo "  Battery + lid closed -> suspends (safe to carry closed)"
echo "Test: on AC, close the lid, then SSH in from another machine - it stays up."
echo "Undo: ./lid-server.sh --revert"

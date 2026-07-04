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

# PowerDevil, Plasma 6. Two INDEPENDENT settings both suspend the machine, so
# server-on-AC needs BOTH zeroed (verified against the powerdevil source):
#   LidAction         - what closing the lid does
#   AutoSuspendAction - the idle timer (default AC timeout 900s/15min -> Sleep)
# Both live under group SuspendAndShutdown (NOT the Plasma 5 `HandleButtonEvents`
# /`lidAction`, which 6.x silently ignores -> falls back to its Sleep default).
# Value enum (daemon/powerdevilenums.h): 0=NoAction(do nothing), 1=Sleep,
# 2=Hibernate, 8=Shutdown, 32=LockScreen, ...  Screen dim/off is a SEPARATE
# group ([AC][Display]) we deliberately leave alone.
PD_GROUP=SuspendAndShutdown
PD_KEY=LidAction
PD_IDLE_KEY=AutoSuspendAction

# Clear any stale Plasma-5-style keys a previous version of this script wrote.
clear_legacy_pd() {
  local p
  for p in AC Battery LowBattery; do
    kwriteconfig6 --file powerdevilrc --group "$p" --group HandleButtonEvents --key lidAction --delete 2>/dev/null || true
  done
}

reload_powerdevil() {
  # PowerDevil reloads via a DBus nudge (what System Settings sends), not a file
  # watch, so a hand-edit needs a reload. Restart is the reliable way in-session.
  systemctl --user restart plasma-powerdevil.service 2>/dev/null \
    || qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement refreshStatus 2>/dev/null \
    || true
}

if [[ "${1:-}" == "--revert" ]]; then
  clear_legacy_pd
  kwriteconfig6 --file powerdevilrc --group AC         --group "$PD_GROUP" --key "$PD_KEY" 1
  kwriteconfig6 --file powerdevilrc --group Battery    --group "$PD_GROUP" --key "$PD_KEY" 1
  kwriteconfig6 --file powerdevilrc --group LowBattery --group "$PD_GROUP" --key "$PD_KEY" 1
  # Restore the stock AC idle-suspend (drop our override so the 15-min default returns).
  kwriteconfig6 --file powerdevilrc --group AC --group "$PD_GROUP" --key "$PD_IDLE_KEY" --delete 2>/dev/null || true
  reload_powerdevil
  sudo rm -f "$LOGIND_SNIPPET"
  # reload (SIGHUP), NOT restart: restarting logind in a live graphical session
  # tears down the seat and crashes the compositor (login loop). reload re-reads
  # config without touching sessions.
  sudo systemctl reload systemd-logind
  echo "Reverted: closing the lid suspends on AC and on battery (KDE default)."
  exit 0
fi

# --- 1. KDE PowerDevil (authority while logged in) --------------------------
clear_legacy_pd
kwriteconfig6 --file powerdevilrc --group AC         --group "$PD_GROUP" --key "$PD_KEY" 0
kwriteconfig6 --file powerdevilrc --group Battery    --group "$PD_GROUP" --key "$PD_KEY" 1
kwriteconfig6 --file powerdevilrc --group LowBattery --group "$PD_GROUP" --key "$PD_KEY" 1
# Also disable the AC idle-suspend timer (15-min default) so it stays up like a
# server; battery/low-battery keep their defaults so an unplugged laptop sleeps.
kwriteconfig6 --file powerdevilrc --group AC         --group "$PD_GROUP" --key "$PD_IDLE_KEY" 0
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
# logind must never idle-suspend on its own (belt-and-suspenders; PowerDevil
# already governs battery idle). Default is already 'ignore' - pin it explicit.
IdleAction=ignore
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

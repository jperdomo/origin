#!/usr/bin/env bash
#
# asusd-deploy.sh - Deploy the asusctl root daemon on Bazzite.
#
# The `asusctl-linux` Homebrew cask (ublue-os/tap) ships the asusd daemon as a
# payload that its postflight is supposed to `sudo install` into /opt + /etc.
# Under Bazzite that postflight fails ("sudo: a password is required") because
# brew's subprocess can't get an interactive sudo prompt. This script performs
# the exact same deploy steps by hand, including SELinux contexts, then enables
# the services.
#
# Re-run this after every `brew upgrade`/`reinstall` of asusctl-linux.

set -euo pipefail

BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
CASKROOM="$BREW_PREFIX/Caskroom/asusctl-linux"

[[ -d "$CASKROOM" ]] || { echo "asusctl-linux cask not installed (no $CASKROOM)"; exit 1; }

# Newest installed version dir
STAGED="$(ls -1d "$CASKROOM"/*/ 2>/dev/null | sort -V | tail -1)"
STAGED="${STAGED%/}"
REL="$(ls -1d "$STAGED"/asusctl-*-ubuntu-*/ 2>/dev/null | tail -1)"
REL="${REL%/}"
[[ -n "$REL" && -f "$REL/usr/bin/asusd" ]] || { echo "asusd payload not found under $STAGED"; exit 1; }

ROOT=/opt/ublue-asusctl
ROOT_BIN="$ROOT/bin"
ROOT_ASUSD="$ROOT/share/asusd"
SYSD=/etc/systemd/system
UDEV=/etc/udev/rules.d
DBUS=/etc/dbus-1/system.d
CFG=/etc/asusd

echo ":: Deploying asusd payload from $REL"
sudo install -d "$ROOT_BIN" "$ROOT_ASUSD" "$SYSD" "$UDEV" "$DBUS" "$CFG"
sudo install -Dm0755 "$REL/usr/bin/asusd"          "$ROOT_BIN/asusd"
sudo install -Dm0755 "$REL/usr/bin/asus-shutdown"  "$ROOT_BIN/asus-shutdown"
sudo cp -a "$REL/usr/share/asusd/." "$ROOT_ASUSD/"

# Processed unit files (ExecStart already rewritten to /opt paths by the cask)
sudo install -Dm0644 "$STAGED/asusd.service"          "$SYSD/asusd.service"
sudo install -Dm0644 "$STAGED/asus-shutdown.service"  "$SYSD/asus-shutdown.service"
sudo install -Dm0644 "$STAGED/asusd.env"              "$CFG/asusd.env"
sudo install -Dm0644 "$REL/usr/lib/udev/rules.d/99-asusd.rules" "$UDEV/99-asusd.rules"
sudo install -Dm0644 "$REL/usr/share/dbus-1/system.d/asusd.conf" "$DBUS/asusd.conf"

# SELinux: the daemon runs from /opt, so it needs a bin_t label to be exec'able.
if [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
  echo ":: Applying SELinux bin_t context to $ROOT_BIN"
  if command -v semanage >/dev/null 2>&1; then
    sudo semanage fcontext -a -t bin_t "$ROOT_BIN(/.*)?" 2>/dev/null \
      || sudo semanage fcontext -m -t bin_t "$ROOT_BIN(/.*)?"
  elif command -v chcon >/dev/null 2>&1; then
    sudo chcon -R -t bin_t "$ROOT_BIN"
  fi
  command -v restorecon >/dev/null 2>&1 && \
    for p in "$ROOT" "$SYSD" "$UDEV" "$DBUS" "$CFG"; do sudo restorecon -RF "$p"; done
fi

echo ":: Reloading systemd + udev"
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo udevadm trigger

echo ":: Enabling services"
sudo systemctl enable --now asusd.service
systemctl --user daemon-reload
systemctl --user enable --now asusd-user.service 2>/dev/null || true

echo ":: asusd is $(systemctl is-active asusd)"

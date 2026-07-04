#!/usr/bin/env bash
#
# lighting-service.sh - install a user systemd service that re-applies the
# ROG lighting defaults (slash solid/dimmed + keyboard colour) on every login.
#
# asusd.service has no [Install] section and doesn't always restore lighting
# after a reboot, so we re-apply it ourselves at graphical login.
#
# Usage:
#   ./lighting-service.sh            # install + enable
#   ./lighting-service.sh --remove   # disable + remove

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIGHTING="$SCRIPT_DIR/lighting.sh"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="$UNIT_DIR/rog-lighting.service"

if [[ "${1:-}" == "--remove" ]]; then
  systemctl --user disable --now rog-lighting.service 2>/dev/null || true
  rm -f "$UNIT"
  systemctl --user daemon-reload
  echo ":: Removed rog-lighting.service"
  exit 0
fi

[[ -f "$LIGHTING" ]] || { echo "lighting.sh not found at $LIGHTING"; exit 1; }
mkdir -p "$UNIT_DIR"

cat > "$UNIT" <<EOF
[Unit]
Description=Apply ROG G14 lighting defaults (slash + keyboard)
# asusd is a system service; by graphical login it's up. Order after the
# user-facing asusd user daemon when present.
After=asusd-user.service graphical-session.target
Wants=asusd-user.service

[Service]
Type=oneshot
# asusd/dbus can lag a moment at login; give it a beat, then apply.
ExecStartPre=/usr/bin/sleep 3
ExecStart=/usr/bin/env bash "$LIGHTING" --defaults
# Don't fail login if asusd isn't ready; the next login retries.
SuccessExitStatus=0 1

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now rog-lighting.service 2>&1 | tail -1 || true
echo ":: Installed and enabled rog-lighting.service"
echo ":: ExecStart -> $LIGHTING --defaults"

#!/usr/bin/env bash
#
# pin-to-dock.sh - Pin an app to the KDE Plasma Task Manager (the dock) via the
# Plasma scripting API, so it shows as a launcher in the dock/panel.
#
# Usage:  ./pin-to-dock.sh com.brave.Browser.desktop
#
# Works with either the WhiteSur dock or the default Bazzite panel task manager.
# Idempotent: won't add a duplicate if already pinned.

set -euo pipefail

APP="${1:?usage: pin-to-dock.sh <desktop-id, e.g. com.brave.Browser.desktop>}"
LAUNCHER="applications:${APP}"

QDBUS="$(command -v qdbus6 || command -v qdbus || true)"
[[ -n "$QDBUS" ]] || { echo "pin-to-dock: qdbus not found (KDE not running?)"; exit 1; }

# Plasma desktop script: find the Icons-Only/Task Manager widget in any panel
# and append our launcher to its General.launchers config.
SCRIPT="$(cat <<EOF
var targets = ["org.kde.plasma.icontasks", "org.kde.plasma.taskmanager"];
var state = "no-taskmanager";
var ps = panels();
for (var i = 0; i < ps.length; i++) {
  var ids = ps[i].widgetIds;
  for (var j = 0; j < ids.length; j++) {
    var w = ps[i].widgetById(ids[j]);
    if (!w) continue;
    if (targets.indexOf(w.type) >= 0) {
      w.currentConfigGroup = ["General"];
      var cur = String(w.readConfig("launchers", ""));
      if (cur.indexOf("${APP}") < 0) {
        w.writeConfig("launchers", cur.length ? cur + ",${LAUNCHER}" : "${LAUNCHER}");
        w.reloadConfig();
        state = "pinned";
      } else {
        state = "already-pinned";
      }
    }
  }
}
print(state);
EOF
)"

result="$("$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT" 2>/dev/null || true)"
case "$result" in
  pinned)         echo "✓ Pinned $APP to the dock." ;;
  already-pinned) echo "✓ $APP already in the dock." ;;
  no-taskmanager) echo "! No dock/task-manager found to pin to (apply the theme/dock first)." ;;
  *)              echo "! Could not pin $APP (Plasma scripting returned: '${result:-none}')." ;;
esac

#!/usr/bin/env bash
#
# lighting.sh - ROG G14 (GA403) slash + keyboard lighting via asusctl.
#
# Requires the asusctl daemon. Install/deploy it first with:
#   ujust asus install         # brew casks
#   ./asusd-deploy.sh          # deploy root daemon (brew postflight can't sudo on Bazzite)
#
# What it does:
#   * Slash LED bar  -> solid (Static mode), dimmed
#   * Keyboard       -> pick a solid colour (menu of presets or custom hex)
#
# Usage:
#   ./lighting.sh                 # apply slash, then pick a keyboard colour
#   ./lighting.sh --defaults      # apply slash + default keyboard colour, no prompt
#   ./lighting.sh <hex>           # apply slash + set keyboard to <hex> (e.g. 00aaff)
#   ./lighting.sh --slash-only    # just the slash setting
#   ./lighting.sh --brightness N  # override slash brightness (0-255, default 40)

set -euo pipefail

# asusctl lives in Homebrew; make sure it's on PATH for non-interactive shells.
command -v asusctl >/dev/null 2>&1 || {
  [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}
command -v asusctl >/dev/null 2>&1 || { echo "asusctl not found - run 'ujust asus install' first."; exit 1; }
systemctl is-active --quiet asusd || { echo "asusd not running - run ./asusd-deploy.sh first."; exit 1; }

SLASH_BRIGHTNESS=40           # 0-255; low = dimmed
DEFAULT_KB_COLOR="8800ff"     # purple - the default keyboard colour

# --- args ------------------------------------------------------------------
KB_COLOR=""; SLASH_ONLY=false; USE_DEFAULTS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --defaults)    USE_DEFAULTS=true; shift ;;
    --slash-only)  SLASH_ONLY=true; shift ;;
    --brightness)  SLASH_BRIGHTNESS="$2"; shift 2 ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)             KB_COLOR="${1#\#}"; shift ;;   # bare hex, strip leading #
  esac
done

# --defaults: skip the picker and use the default keyboard colour
$USE_DEFAULTS && [[ -z "$KB_COLOR" ]] && KB_COLOR="$DEFAULT_KB_COLOR"

# --- slash: solid + dimmed -------------------------------------------------
echo ":: Slash -> Static (solid), brightness $SLASH_BRIGHTNESS"
asusctl slash --enable --mode Static -l "$SLASH_BRIGHTNESS"

$SLASH_ONLY && { echo ":: Done (slash only)."; exit 0; }

# --- keyboard colour -------------------------------------------------------
# name|hex   (bazzite/gum menu shows the names)
PRESETS=(
  "Warm white|ffb86c"
  "Cool white|f5f5ff"
  "Red|ff0000"
  "Orange|ff6600"
  "Yellow|ffcc00"
  "Green|00ff66"
  "Teal|00ffcc"
  "Cyan|00aaff"
  "Blue|0033ff"
  "Purple|8800ff"
  "Magenta|ff00aa"
  "Pink|ff66cc"
)

if [[ -z "$KB_COLOR" ]]; then
  if command -v gum >/dev/null 2>&1; then
    labels=(); for p in "${PRESETS[@]}"; do labels+=("${p%%|*}"); done
    labels+=("Custom hex…")
    choice="$(printf '%s\n' "${labels[@]}" | gum choose --header="Keyboard colour:")"
    if [[ "$choice" == "Custom hex…" ]]; then
      KB_COLOR="$(gum input --placeholder="RRGGBB e.g. 00aaff")"
      KB_COLOR="${KB_COLOR#\#}"
    else
      for p in "${PRESETS[@]}"; do [[ "${p%%|*}" == "$choice" ]] && KB_COLOR="${p##*|}"; done
    fi
  else
    echo "Keyboard colour (enter a hex like 00aaff, or a preset number):"
    i=1; for p in "${PRESETS[@]}"; do printf "  %2d) %-12s #%s\n" "$i" "${p%%|*}" "${p##*|}"; ((i++)); done
    read -r -p "> " reply
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply>=1 && reply<=${#PRESETS[@]} )); then
      KB_COLOR="${PRESETS[$((reply-1))]##*|}"
    else
      KB_COLOR="${reply#\#}"
    fi
  fi
fi

[[ -z "$KB_COLOR" ]] && { echo ":: No colour chosen; leaving keyboard as-is."; exit 0; }
if ! [[ "$KB_COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
  echo "Invalid colour '$KB_COLOR' (want 6 hex digits, e.g. 00aaff)." >&2; exit 1
fi

echo ":: Keyboard -> static #$KB_COLOR"
asusctl aura effect static -c "$KB_COLOR"
echo ":: Done."

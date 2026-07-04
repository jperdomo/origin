#!/usr/bin/env bash
#
# configure-bazzite.sh - Configure a fresh Bazzite install the way I like it.
#
# Basics always run (idempotent). Optional setups are presented as a tabbed
# series of grouped multi-select "cards" (a small built-in TUI) - step through
# each category, toggle items, Enter advances. Selections then run in order.
# Set NO_TUI=1 for a plain numbered prompt; DRY_RUN=1 to preview without running.
#
# Usage:
#   ./configure-bazzite.sh                 # basics, then step through grouped menus
#   ./configure-bazzite.sh --basics-only   # basics and exit
#   ./configure-bazzite.sh --list          # list groups + optional setup keys
#   ./configure-bazzite.sh perf lighting   # basics + named setups (skip menus)
#   ./configure-bazzite.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- pretty output ---------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'; RESET=$'\e[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi
info()  { echo "${BLUE}${BOLD}::${RESET} $*"; }
ok()    { echo "${GREEN}${BOLD}✓${RESET} $*"; }
warn()  { echo "${YELLOW}${BOLD}!${RESET} $*" >&2; }
err()   { echo "${RED}${BOLD}✗${RESET} $*" >&2; }
step()  { echo; echo "${BOLD}==> $*${RESET}"; }

ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

run_path() {
  # run_path <repo-relative-script> [args...]  -- args are forwarded to the script
  local s="$REPO_ROOT/$1"
  [[ -f "$s" ]] || { err "Missing script: $1 (skipping)"; return 1; }
  info "Running ${DIM}$1${RESET}"
  bash "$s" "${@:2}"
}

# ---------------------------------------------------------------------------
# Optional setups, grouped into logical "tabs".
# Format per entry:  Group|key|Label|action
# Groups are shown (and run) in first-seen order.
# ---------------------------------------------------------------------------
ITEMS=(
  "Apps & Browsers|brave|Brave browser (Flatpak)|setup_brave"
  "Apps & Browsers|ptyxis|Ptyxis terminal: default+dark+icon+dock  [NEEDS REBOOT]|setup_ptyxis"

  "Power & Performance|perf|Set Performance power profile|setup_perf"
  "Power & Performance|dboost|Enable NVIDIA Dynamic Boost (fixes dGPU stuck at 180MHz)|setup_dgpu_boost"
  "Power & Performance|lidserver|Run like a server: lid closed on AC stays awake|run_path bazzite/scripts/lid-server.sh"

  "G14 Hardware & Lighting|asus|Install asusctl + ROG Control Center|setup_asus"
  "G14 Hardware & Lighting|lighting|Slash solid/dimmed + keyboard colour|setup_lighting"
  "G14 Hardware & Lighting|m4key|Bind M4 key to open ROG Control Center|run_path g14/m4-bind.sh"

  "Networking & Remote Access|ssh|Enable SSH server (on boot)|setup_ssh"
  "Networking & Remote Access|tailscale|Enable Tailscale VPN (then: sudo tailscale up)|setup_tailscale"

  "Virtualization & Containers|virt|Virtualization (ujust setup-virtualization)|run_path bazzite/scripts/virt.sh"
  "Virtualization & Containers|cockpit|Cockpit web console (ujust cockpit)|ujust cockpit enable"
  "Virtualization & Containers|ollama|Ollama on Podman (ROCm)|run_path bazzite/scripts/ollama-podman.sh"

  "Desktop Theme|theme|macOS (WhiteSur) look: dark theme, top bar, dock, single-bar|run_path bazzite/scripts/kde-macos-theme.sh"
  "Desktop Theme|kde-dark|Stock KDE Breeze Dark (revert from macOS; panels kept)|run_path bazzite/scripts/kde-default-dark.sh"

  "System Fixes|nmtui|Fix layered NetworkManager-tui conflict|run_path bazzite/scripts/nmtui.sh"
)

# One-line description per key, shown under each option in the menu (ASCII only
# so the box padding stays aligned).
declare -A DESC=(
  [brave]="Fast Chromium browser, installed as a Flatpak"
  [ptyxis]="rpm-ostree layers Ptyxis (REBOOT needed), then re-run: default terminal + dark + gray icon + first in dock"
  [perf]="Performance power profile (moot on G14: asusd owns it)"
  [dboost]="Enable nvidia-powerd (Dynamic Boost) so the laptop dGPU can raise clocks under load"
  [lidserver]="Lid closed on AC keeps running (KDE + logind); on battery it still suspends"
  [asus]="asusctl + ROG Control Center; deploys the asusd daemon"
  [lighting]="Slash solid/dimmed + keyboard purple; persists at login"
  [m4key]="Bind M4 (XF86Launch1) to launch ROG Control Center"
  [ssh]="Enable + start sshd (OpenSSH) so you can SSH in; via 'ujust ssh enable'"
  [tailscale]="Enable the tailscaled daemon (ujust); then run 'sudo tailscale up' to join your tailnet"
  [virt]="Enable KVM/libvirt via 'ujust setup-virtualization'"
  [cockpit]="Cockpit web console on https://localhost:9090"
  [ollama]="Ollama LLM server on Podman (ROCm / AMD GPU)"
  [theme]="WhiteSur dark + purple icons, macOS top bar + dock, removes old bottom bar"
  [kde-dark]="Revert to stock KDE Breeze Dark (colours/deco/icons); panels & dock untouched"
  [nmtui]="Remove layered NetworkManager-tui (base-image conflict)"
)

# field accessors (delimiter is '|', fields never contain it)
f_group()  { echo "${1%%|*}"; }
f_key()    { local r="${1#*|}"; echo "${r%%|*}"; }
f_label()  { local r="${1#*|}"; r="${r#*|}"; echo "${r%%|*}"; }
f_action() { echo "${1##*|}"; }

groups_in_order() {
  local seen="" g
  for item in "${ITEMS[@]}"; do
    g="$(f_group "$item")"
    [[ "$seen" == *"<$g>"* ]] || { echo "$g"; seen+="<$g>"; }
  done
}

# --- basics (always run) ---------------------------------------------------
basics() {
  step "Basics"
  ensure_brew

  if command -v gh >/dev/null 2>&1; then
    ok "gh already installed ($(gh --version | head -1))"
  elif command -v brew >/dev/null 2>&1; then
    info "Installing gh via Homebrew"; brew install gh; ok "gh installed"
  else
    err "brew not found - cannot install gh."
  fi

  local motd_flag="${HOME}/.config/no-show-user-motd"
  if [[ -e "$motd_flag" ]]; then
    ok "user-motd already disabled"
  elif command -v ujust >/dev/null 2>&1; then
    info "Disabling user-motd (ujust toggle-user-motd)"; ujust toggle-user-motd; ok "user-motd disabled"
  else
    mkdir -p "${HOME}/.config" && touch "$motd_flag"; ok "user-motd disabled"
  fi
}

# --- setup actions ---------------------------------------------------------
setup_brave() {
  ensure_brew
  if flatpak info com.brave.Browser >/dev/null 2>&1; then ok "Brave already installed"; return 0; fi
  info "Installing Brave via Flatpak (Flathub)"; flatpak install -y flathub com.brave.Browser; ok "Brave installed"
}

setup_ptyxis() {
  # Phase 1: not installed -> rpm-ostree layer it (needs a reboot). Flatpak can't
  # be a real default terminal, so we layer per the researched recommendation.
  if ! command -v ptyxis >/dev/null 2>&1; then
    if rpm-ostree status 2>/dev/null | grep -qw ptyxis; then
      warn "Ptyxis is layered but not active until you REBOOT."
      warn "After reboot, re-run:  ./configure-bazzite.sh ptyxis  (sets default + dark + dock)"
      return 0
    fi
    info "Layering Ptyxis via rpm-ostree ${BOLD}(REBOOT REQUIRED)${RESET}"
    if sudo rpm-ostree install ptyxis; then
      ok "Ptyxis layered."
      warn "${BOLD}REBOOT now${RESET} (systemctl reboot), then re-run:  ./configure-bazzite.sh ptyxis"
      warn "  That second run sets Ptyxis as the default terminal, dark, and first in the dock."
    else
      err "rpm-ostree install ptyxis failed."
    fi
    return 0
  fi

  # Phase 2: Ptyxis is installed & active (post-reboot).
  info "Ptyxis -> default terminal"
  kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ptyxis
  kwriteconfig6 --file kdeglobals --group General --key TerminalService org.gnome.Ptyxis.desktop

  info "Ptyxis -> dark"
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
  gsettings set org.gnome.Ptyxis interface-style dark 2>/dev/null \
    || dconf write /org/gnome/Ptyxis/interface-style "'dark'" 2>/dev/null \
    || warn "couldn't force Ptyxis dark via gsettings; it follows the system prefer-dark (which is set)"

  info "Ptyxis -> standard gray terminal icon (replacing the green default)"
  local apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  local sys_desktop="" d
  for d in /usr/share/applications /var/lib/flatpak/exports/share/applications \
           "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications"; do
    [[ -f "$d/org.gnome.Ptyxis.desktop" ]] && { sys_desktop="$d/org.gnome.Ptyxis.desktop"; break; }
  done
  if [[ -n "$sys_desktop" ]]; then
    mkdir -p "$apps_dir"
    # A user override with the same ID replaces the system entry wholesale, so
    # copy it and rewrite every Icon= line (main entry + any Desktop Action
    # groups) to the generic 'utilities-terminal', which the icon theme draws as
    # a neutral gray terminal instead of Ptyxis's green branded icon.
    sed -E 's/^Icon=.*/Icon=utilities-terminal/' "$sys_desktop" > "$apps_dir/org.gnome.Ptyxis.desktop"
    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    ok "Ptyxis icon -> utilities-terminal (gray)"
  else
    warn "Ptyxis desktop file not found; icon left unchanged"
  fi

  info "Ptyxis -> first in the dock (removing Konsole)"
  local f="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
  local py="$REPO_ROOT/bazzite/scripts/kde-dock-launchers.py"
  if [[ -f "$f" && -f "$py" ]]; then
    cp "$f" "$f.bak" 2>/dev/null || true
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    local n; for n in $(seq 1 20); do pgrep -x plasmashell >/dev/null 2>&1 || break; sleep 0.5; done
    python3 "$py" "$f" --prepend org.gnome.Ptyxis.desktop --remove org.kde.konsole.desktop || warn "dock launcher edit failed"
    (command -v kstart6 >/dev/null 2>&1 && kstart6 plasmashell || kstart plasmashell || setsid plasmashell) >/dev/null 2>&1 &
  else
    warn "dock config or helper missing; skipped dock change"
  fi
  ok "Ptyxis: default terminal + dark + gray icon + first in dock. Log out/in to settle."
}

setup_dgpu_boost() {
  # NVIDIA Dynamic Boost daemon. Bazzite driver images sometimes ship it
  # DISABLED, which pins the laptop dGPU at its idle clock (~180MHz) even under
  # 100% load - the fix for the G14 5070 Ti "stuck clock / bad FPS". Enabling it
  # lets the dGPU raise power/clocks; --now + enable persists across reboots.
  if ! systemctl cat nvidia-powerd.service >/dev/null 2>&1; then
    warn "nvidia-powerd.service not present (no NVIDIA dGPU driver here?) - skipping"
    return 0
  fi
  # Check ENABLED, not active: the daemon legitimately idles/skips when the GPU
  # isn't in use (ConditionPathExistsGlob=/dev/nvidia*), so "inactive" is normal.
  if systemctl is-enabled --quiet nvidia-powerd 2>/dev/null; then
    ok "NVIDIA Dynamic Boost (nvidia-powerd) already enabled (starts at boot on demand)"
    return 0
  fi
  info "Enabling NVIDIA Dynamic Boost (nvidia-powerd) so the dGPU can boost clocks"
  if sudo systemctl enable --now nvidia-powerd 2>/dev/null || sudo systemctl enable nvidia-powerd; then
    ok "nvidia-powerd enabled (persists across reboots; starts when the dGPU is active)"
  else
    err "failed to enable nvidia-powerd"
  fi
}

setup_perf() {
  info "Setting power profile to Performance"
  if busctl --system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
       net.hadess.PowerProfiles ActiveProfile s performance 2>/dev/null; then
    ok "Power profile -> performance ($(tuned-adm active 2>/dev/null | cut -d: -f2 | xargs))"
  else
    warn "power-profiles-daemon unavailable; falling back to tuned"
    sudo tuned-adm profile throughput-performance-bazzite
  fi
}

setup_ssh() {
  # Enable the OpenSSH server on boot. Bazzite ships a 'ujust ssh' recipe that
  # enables+starts sshd (and prints your IP); fall back to systemctl directly.
  local ip; ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if systemctl is-enabled --quiet sshd 2>/dev/null; then
    ok "SSH already enabled  (ssh ${USER}@${ip:-<ip>})"; return 0
  fi
  info "Enabling SSH server on boot"
  if command -v ujust >/dev/null 2>&1; then
    ujust ssh enable
  else
    sudo systemctl enable --now sshd
  fi
  ok "SSH enabled  ->  ssh ${USER}@${ip:-<ip>}"
}

setup_tailscale() {
  # Enable the tailscaled daemon (via Bazzite's 'ujust tailscale' recipe). That
  # only starts the service; you still authenticate once with 'sudo tailscale up'.
  if systemctl is-enabled --quiet tailscaled 2>/dev/null; then
    ok "Tailscale daemon already enabled"
  else
    info "Enabling Tailscale daemon"
    if command -v ujust >/dev/null 2>&1; then
      ujust tailscale enable
    else
      sudo systemctl enable --now tailscaled
    fi
    ok "tailscaled enabled"
  fi
  # Connected yet? 'tailscale status' exits nonzero (or says Logged out) when not up.
  if tailscale status >/dev/null 2>&1; then
    ok "Tailscale is up  ($(tailscale ip -4 2>/dev/null | head -1))"
  else
    warn "Tailscale daemon is running but not connected."
    warn "  Run:  ${BOLD}sudo tailscale up${RESET}   to log in and join your tailnet."
  fi
}

setup_asus() {
  # asusctl on Bazzite = brew casks from ublue tap; the root daemon needs a
  # manual deploy (brew's postflight can't sudo here) via g14/asusd-deploy.sh.
  ensure_brew
  if command -v asusctl >/dev/null 2>&1 && systemctl is-active --quiet asusd; then
    ok "asusctl already installed and asusd running"; return 0
  fi
  info "Installing asusctl + ROG Control Center (brew casks)"
  brew tap ublue-os/tap >/dev/null 2>&1 || true
  brew trust ublue-os/tap 2>/dev/null || true
  brew install --cask asusctl-linux rog-control-center-linux
  info "Deploying asusd root daemon"
  run_path g14/asusd-deploy.sh

  # asusd owns the platform profile on the G14; mask tuned/tuned-ppd so they
  # don't fight over it (KDE power-profile toggle stops working - manage via
  # ROG Control Center / asusctl instead).
  if systemctl is-active --quiet tuned || systemctl is-enabled --quiet tuned 2>/dev/null; then
    info "Masking tuned/tuned-ppd (asusd owns power profiles)"
    sudo systemctl mask --now tuned tuned-ppd 2>/dev/null || sudo systemctl mask --now tuned
    ok "tuned masked"
  fi

  # Apply the default lighting (slash solid/dimmed + keyboard purple)...
  info "Applying default lighting"
  run_path g14/lighting.sh --defaults || warn "Lighting defaults skipped"
  # ...and make it persist across reboots via a user login service.
  info "Installing lighting persistence service"
  run_path g14/lighting-service.sh || warn "Lighting service install skipped"
}

# Keyboard colours for the lighting sub-card (name:hex; purple first = default).
KB_COLORS=("Purple:8800ff" "Blue:0033ff" "Teal:00ffcc" "Cyan:00aaff" "Green:00ff66"
           "Red:ff0000" "Orange:ff6600" "Warm white:ffb86c" "Cool white:f5f5ff")

# Single-select colour card; sets global KB_HEX. Uses the TUI helpers (defined
# below; available by the time this runs). q/Esc keeps the default (purple).
pick_kb_color() {
  KB_HEX="8800ff"
  local names=() hexes=() c; for c in "${KB_COLORS[@]}"; do names+=("${c%%:*}"); hexes+=("${c##*:}"); done
  local cur=0 n=${#names[@]} key rest W bar i
  while true; do
    W="$(tui_width)"; bar="$(printf '─%.0s' $(seq 1 $((W + 2))))"
    printf '\033[2J\033[H'
    printf '%b╭%s╮%b\n' "$BLUE$BOLD" "$bar" "$RESET"
    crow "$W" "Keyboard colour" "$BLUE$BOLD"
    printf '%b├%s┤%b\n' "$BLUE$BOLD" "$bar" "$RESET"
    for i in "${!names[@]}"; do
      local mark="   "; [[ "$i" == "$cur" ]] && mark=" > "
      local line; printf -v line '%s%d. %-12s #%s' "$mark" "$((i + 1))" "${names[$i]}" "${hexes[$i]}"
      if [[ "$i" == "$cur" ]]; then crow "$W" "$line" "$GREEN$BOLD"; else row "$W" "$line"; fi
    done
    printf '%b├%s┤%b\n' "$BLUE$BOLD" "$bar" "$RESET"
    row "$W" "  arrows move   #/enter select   q = default (purple)"
    printf '%b╰%s╯%b\n' "$BLUE$BOLD" "$bar" "$RESET"
    IFS= read -rsn1 key || break
    case "$key" in
      $'\e') read -rsn2 -t 0.05 rest || true
             case "$rest" in '[A') cur=$(( (cur - 1 + n) % n ));; '[B') cur=$(( (cur + 1) % n ));; esac ;;
      [1-9]) local si=$(( key - 1 )); [[ $si -lt $n ]] && { KB_HEX="${hexes[$si]}"; break; } ;;
      ''|$'\n') KB_HEX="${hexes[$cur]}"; break ;;
      q|Q) break ;;
    esac
  done
  printf '\033[2J\033[H'
  return 0
}

# Lighting: interactive -> colour sub-card then apply; non-interactive -> purple default.
setup_lighting() {
  local interactive=1
  { [[ -t 0 && -t 1 ]] && [[ -z "${NO_TUI:-}" ]]; } || interactive=0
  if [[ $interactive == 1 ]]; then
    pick_kb_color
    run_path g14/lighting.sh "$KB_HEX"
  else
    run_path g14/lighting.sh --defaults
  fi
}

# Best-effort "already done?" check so re-runs show what's installed.
item_done() {
  case "$1" in
    brave)    flatpak info com.brave.Browser >/dev/null 2>&1 ;;
    ptyxis)   command -v ptyxis >/dev/null 2>&1 ;;
    dboost)   systemctl is-enabled --quiet nvidia-powerd 2>/dev/null ;;
    asus)     command -v asusctl >/dev/null 2>&1 && systemctl is-active --quiet asusd ;;
    lighting) systemctl --user is-enabled --quiet rog-lighting.service 2>/dev/null ;;
    theme)    [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/look-and-feel/com.github.vinceliuice.WhiteSur-dark" ]] ;;
    ollama)   podman container exists ollama 2>/dev/null ;;
    lidserver) [[ -f /etc/systemd/logind.conf.d/99-g14-server-lid.conf ]] ;;
    ssh)       systemctl is-enabled --quiet sshd 2>/dev/null ;;
    tailscale) systemctl is-enabled --quiet tailscaled 2>/dev/null ;;
    *)        return 1 ;;   # unknown/unchecked -> treat as not-done
  esac
}

# --- menus -----------------------------------------------------------------
usage() {
  cat <<EOF
${BOLD}configure-bazzite.sh${RESET} - configure Bazzite the way I like it.

Basics (always run, idempotent): install gh (brew), disable terminal user-motd.

Optional setups are grouped and presented as a tabbed series of multi-selects.

Usage:
  $(basename "$0")                 basics, then step through grouped menus
  $(basename "$0") --basics-only   basics and exit
  $(basename "$0") --list          list groups + setup keys
  $(basename "$0") <key> [key...]  basics + named setups (no menus)
  $(basename "$0") --help

Optional setups:
$(list_optional)
EOF
}

list_optional() {
  local g
  while IFS= read -r g; do
    echo "  ${BOLD}$g${RESET}"
    for item in "${ITEMS[@]}"; do
      [[ "$(f_group "$item")" == "$g" ]] && printf "    %-9s %s\n" "$(f_key "$item")" "$(f_label "$item")"
    done
  done < <(groups_in_order)
}

# Two-phase menu: (1) pick which sections to configure, (2) toggle items in
# only those sections. A generic "card" multi-select drives both phases.
declare -A PICK                                  # PICK[key]=1 means "install this run"
declare -a CARD_LABELS=() CARD_DESCS=() CARD_MARK=() CARD_SEL=()   # current card's data
TUI_QUIT=0
INTERACTIVE=1

# Inner content width; adapt to terminal but cap so the box fits ~66 cols.
tui_width() {
  local c; c="$(tput cols 2>/dev/null || echo 80)"
  local w=$(( c - 6 )); [[ $w -gt 62 ]] && w=62; [[ $w -lt 40 ]] && w=40
  echo "$w"
}
row()  { printf '│ %-*s │\n' "$1" "${2:0:$1}"; }                       # plain padded row
crow() { printf '│ %b%-*s%b │\n' "$3" "$1" "${2:0:$1}" "$RESET"; }     # coloured padded row

# Draw the current card (uses CARD_LABELS/CARD_DESCS/CARD_MARK/CARD_SEL). ASCII
# content only, so %-*s pads by column; box chars sit outside the padded field.
card_draw() {
  local title="$1" idx="$2" total="$3" cur="$4" W; W="$(tui_width)"
  local bar; bar="$(printf '─%.0s' $(seq 1 $((W + 2))))"
  local tag="[$idx/$total]" head; printf -v head '%s%*s' "$title" "$(( W - ${#title} ))" "$tag"
  printf '\033[2J\033[H'
  printf '%b╭%s╮%b\n' "$BLUE$BOLD" "$bar" "$RESET"
  crow "$W" "$head" "$BLUE$BOLD"
  printf '%b├%s┤%b\n' "$BLUE$BOLD" "$bar" "$RESET"
  local i
  for i in "${!CARD_LABELS[@]}"; do
    local box="[ ]" mark="  "
    [[ "${CARD_SEL[$i]}" == 1 ]] && box="[x]"
    [[ "$i" == "$cur" ]] && mark="> "
    local line; printf -v line '%s%s %d. %s%s' "$mark" "$box" "$((i + 1))" "${CARD_LABELS[$i]}" "${CARD_MARK[$i]:-}"
    if [[ "$i" == "$cur" ]]; then crow "$W" "$line" "$GREEN$BOLD"; else row "$W" "$line"; fi
    local dline; printf -v dline '       %s' "${CARD_DESCS[$i]:-}"
    crow "$W" "$dline" "$DIM"
  done
  printf '%b├%s┤%b\n' "$BLUE$BOLD" "$bar" "$RESET"
  row "$W" "  arrows move   space/# toggle   enter confirm   q quit"
  printf '%b╰%s╯%b\n' "$BLUE$BOLD" "$bar" "$RESET"
}

# Interactive card: arrows/number keys toggle CARD_SEL, Enter confirms, q quits.
card_run() {
  local title="$1" idx="$2" total="$3" cur=0 n=${#CARD_LABELS[@]} key rest
  while true; do
    card_draw "$title" "$idx" "$total" "$cur"
    IFS= read -rsn1 key || { TUI_QUIT=1; break; }
    case "$key" in
      $'\e') read -rsn2 -t 0.05 rest || true
             case "$rest" in
               '[A') cur=$(( (cur - 1 + n) % n ));;
               '[B') cur=$(( (cur + 1) % n ));;
             esac ;;
      ' ')       CARD_SEL[$cur]=$(( 1 - ${CARD_SEL[$cur]} )) ;;
      [1-9])     local si=$(( key - 1 )); [[ $si -lt $n ]] && CARD_SEL[$si]=$(( 1 - ${CARD_SEL[$si]} )) ;;
      ''|$'\n')  break ;;
      q|Q)       TUI_QUIT=1; break ;;
    esac
  done
  return 0
}

# Non-interactive fallback (no TTY, or NO_TUI=1): plain numbered prompt. Testable.
card_numbered() {
  local title="$1" idx="$2" total="$3" i
  echo >&2; echo "[$idx/$total] $title" >&2
  for i in "${!CARD_LABELS[@]}"; do
    printf "  %d) %s%s\n" "$((i + 1))" "${CARD_LABELS[$i]}" "${CARD_MARK[$i]:-}" >&2
    [[ -n "${CARD_DESCS[$i]:-}" ]] && printf "       %s\n" "${CARD_DESCS[$i]}" >&2
  done
  local reply; read -r -p "Select numbers (space-separated, enter=skip): " reply || reply=""
  local n
  for n in $reply; do
    [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#CARD_LABELS[@]}" ] && CARD_SEL[$((n - 1))]=1
  done
  return 0
}

card_pick() { [[ "$INTERACTIVE" == 1 ]] && card_run "$@" || card_numbered "$@"; }
clear_screen() { [[ "$INTERACTIVE" == 1 ]] && printf '\033[2J\033[H'; return 0; }

choose_grouped() {
  local groups=(); mapfile -t groups < <(groups_in_order)
  CHOSEN_KEYS=(); PICK=(); TUI_QUIT=0
  INTERACTIVE=1; { [[ -t 0 && -t 1 ]] && [[ -z "${NO_TUI:-}" ]]; } || INTERACTIVE=0

  # ---- Phase 1: which sections? ----
  CARD_LABELS=(); CARD_DESCS=(); CARD_MARK=(); CARD_SEL=()
  local g item
  for g in "${groups[@]}"; do
    local names=() joined=""
    for item in "${ITEMS[@]}"; do [[ "$(f_group "$item")" == "$g" ]] && names+=("$(f_label "$item")"); done
    joined="${names[0]:-}"; local nm; for nm in "${names[@]:1}"; do joined+=", $nm"; done
    CARD_LABELS+=("$g"); CARD_DESCS+=("$joined"); CARD_MARK+=(""); CARD_SEL+=(0)
  done
  card_pick "Which sections to configure?" 1 1
  [[ "$TUI_QUIT" == 1 ]] && { clear_screen; warn "Cancelled."; return 0; }

  local active=() i
  for i in "${!groups[@]}"; do [[ "${CARD_SEL[$i]}" == 1 ]] && active+=("${groups[$i]}"); done
  [[ ${#active[@]} -eq 0 ]] && { clear_screen; return 0; }

  # ---- Phase 2: toggle items in each chosen section ----
  local total=${#active[@]} idx=0
  for g in "${active[@]}"; do
    idx=$((idx + 1))
    local keys=(); CARD_LABELS=(); CARD_DESCS=(); CARD_MARK=(); CARD_SEL=()
    for item in "${ITEMS[@]}"; do
      if [[ "$(f_group "$item")" == "$g" ]]; then
        local k; k="$(f_key "$item")"; keys+=("$k")
        CARD_LABELS+=("$(f_label "$item")"); CARD_DESCS+=("${DESC[$k]:-}")
        local mk=""; item_done "$k" && mk="  (installed)"; CARD_MARK+=("$mk"); CARD_SEL+=(0)
      fi
    done
    card_pick "$g" "$idx" "$total"
    [[ "$TUI_QUIT" == 1 ]] && { clear_screen; warn "Cancelled."; CHOSEN_KEYS=(); return 0; }
    for i in "${!keys[@]}"; do [[ "${CARD_SEL[$i]}" == 1 ]] && PICK["${keys[$i]}"]=1; done
  done
  clear_screen

  # Build CHOSEN_KEYS in ITEMS (logical) order from the toggled state.
  local k
  for item in "${ITEMS[@]}"; do
    k="$(f_key "$item")"
    [[ "${PICK[$k]:-0}" == 1 ]] && CHOSEN_KEYS+=("$k")
  done
  return 0
}

run_keys() {
  # Run named keys in ITEMS order (logical), not selection order.
  local want=("$@") ran=0
  for item in "${ITEMS[@]}"; do
    local key; key="$(f_key "$item")"
    local hit=false k; for k in "${want[@]}"; do [[ "$k" == "$key" ]] && hit=true; done
    $hit || continue
    ran=1; step "$(f_label "$item")"
    if [[ -n "${DRY_RUN:-}" ]]; then
      echo "[dry-run] would run: $(f_action "$item")"
    else
      eval "$(f_action "$item")" || err "Setup '$key' failed (continuing)"
    fi
  done
  # warn about unknown keys
  local k found
  for k in "${want[@]}"; do
    [[ -z "$k" ]] && continue
    found=false; for item in "${ITEMS[@]}"; do [[ "$(f_key "$item")" == "$k" ]] && found=true; done
    $found || warn "Unknown setup: '$k' (see --list)"
  done
  [[ "$ran" == 0 ]] && info "No optional setups selected."
  return 0   # never let a false [[ ]] here trip set -e in the caller
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --list)    list_optional; exit 0 ;;
  esac

  # Never let a basics hiccup abort the run - you must always reach the setups
  # to add more things on a re-run.
  basics || warn "Some basics steps failed - continuing to optional setups"
  [[ "${1:-}" == "--basics-only" ]] && { echo; ok "Basics done."; exit 0; }

  local keys=()
  if [[ $# -gt 0 ]]; then
    keys=("$@")
  else
    step "Optional setups"
    info "First pick which sections to configure; then toggle items in each."
    choose_grouped            # runs on the terminal, fills CHOSEN_KEYS
    keys=("${CHOSEN_KEYS[@]:-}")
    local real=(); local k; for k in "${keys[@]}"; do [[ -n "$k" ]] && real+=("$k"); done
    [[ ${#real[@]} -gt 0 ]] && info "Selected: ${BOLD}${real[*]}${RESET}"
  fi

  run_keys "${keys[@]:-}"

  # If Brave was set up, pin it to the dock. Done last so it survives the
  # theme's dock/layout reset (which runs during run_keys).
  local wants_brave=false kk
  for kk in "${keys[@]:-}"; do [[ "$kk" == "brave" ]] && wants_brave=true; done
  if $wants_brave; then
    if [[ -n "${DRY_RUN:-}" ]]; then
      echo "[dry-run] would pin Brave to the dock"
    else
      info "Pinning Brave to the dock"
      run_path bazzite/scripts/pin-to-dock.sh com.brave.Browser.desktop || warn "Could not pin Brave to dock"
    fi
  fi

  echo; ok "Done."
}

# Run main unless sourced (sourcing lets the functions be tested in isolation).
# Use if/fi (not &&) so a false test returns 0 and doesn't trip set -e callers.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

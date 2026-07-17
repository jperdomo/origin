#!/usr/bin/env bash
#
# no-sleep.sh - Never sleep. Run a Bazzite box as an always-reachable server:
# no suspend, no hibernate, ever, no matter who asks.
#
# Masks the five sleep targets, so EVERY suspend path fails at the systemd
# layer. That bluntness is the point: on Bazzite the thing that actually puts
# the machine to sleep is usually NOT the setting you'd think to check.
#
#   logind IdleAction     -> already 'ignore' on a stock image; innocent.
#   KDE PowerDevil        -> only governs a Plasma session; irrelevant in Game Mode.
#   Steam Game Mode       -> THE CULPRIT. The Deck UI runs its own idle timer and
#                            calls suspend over DBus through logind. Its "Sleep
#                            after inactivity" toggle is per-user Steam config
#                            that a Steam update or profile reset can undo.
#
# Masking the targets sits UNDER all of them, so Steam's request simply fails.
# There is no ujust recipe for this (toggle-cec-sleep only tells the TV what to
# do WHEN the system sleeps; toggle-i915-sleep-fix is for Intel chips that CAN'T
# sleep - the opposite problem).
#
# Atomic-safe: mask writes symlinks into /etc/systemd/system, and /etc is
# writable and persists across rpm-ostree updates. Shows up in
# 'ujust check-local-overrides', which is where you'd want to find it later.
#
# NOT for laptops you carry: this kills lid-close suspend on battery too. For a
# laptop that should stay up on AC but still sleep in a bag, use lid-server.sh
# instead - it's the nuanced version of this idea. (Running both is coherent:
# lid-server governs the lid, this vetoes sleep outright, and this one wins.)
#
# Hibernate note: it's masked here for completeness, but on a stock Bazzite box
# it can't happen anyway - there's no resume= karg and swap is zram only.
#
# Run as your desktop user (it sudos where needed).
# Usage:  ./no-sleep.sh            never sleep (mask the sleep targets)
#         ./no-sleep.sh --revert   restore stock (sleep allowed again)
#         ./no-sleep.sh --status   show current state and exit

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Run as your desktop user, not root (the script sudos where needed)." >&2
  exit 1
fi

# All five: masking sleep.target alone would cover most paths, but suspend.target
# and friends are separate units logind reaches for directly.
TARGETS=(sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target)

status() {
  local t st
  for t in "${TARGETS[@]}"; do
    st="$(systemctl is-enabled "$t" 2>/dev/null || true)"
    printf '  %-30s %s\n' "$t" "${st:-unknown}"
  done
}

if [[ "${1:-}" == "--status" ]]; then
  echo "Sleep targets:"; status
  exit 0
fi

if [[ "${1:-}" == "--revert" ]]; then
  sudo systemctl unmask "${TARGETS[@]}"
  sudo systemctl daemon-reload
  echo "Reverted: the machine can suspend/hibernate again."
  echo
  echo "Sleep targets:"; status
  echo
  echo "Note: in Steam Game Mode the Deck UI's own idle timer resumes control,"
  echo "so it may start sleeping again on idle (Settings > Power)."
  exit 0
fi

# A laptop that gets carried should probably use lid-server.sh instead. Warn,
# don't block - a laptop parked on a desk as a server is a legitimate reason to
# be here on purpose.
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
  echo "! Battery detected: this disables lid-close suspend on battery too." >&2
  echo "  For a laptop you carry, lid-server.sh is the better fit (sleeps in a bag)." >&2
  echo >&2
fi

# Suspending a host out from under running VMs risks corrupting guest
# filesystems, and libvirt only registers a 'delay' inhibitor - which slows
# suspend down but does not veto it. Worth saying out loud, since a VM host is
# exactly the machine you'd run this on.
if command -v virsh >/dev/null 2>&1 && [[ -n "$(virsh -q list --name 2>/dev/null | tr -d '[:space:]')" ]]; then
  echo ":: VMs are running here - masking sleep also protects them from a" >&2
  echo "   mid-flight host suspend (libvirt's inhibitor only delays, never vetoes)." >&2
  echo >&2
fi

sudo systemctl mask "${TARGETS[@]}"
sudo systemctl daemon-reload

# Verify rather than trust: mask is a symlink write, and a pre-existing real file
# at the same path would make it silently not take.
failed=()
for t in "${TARGETS[@]}"; do
  [[ "$(systemctl is-enabled "$t" 2>/dev/null || true)" == "masked" ]] || failed+=("$t")
done

echo
echo "Sleep targets:"; status
echo

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "✗ Not masked: ${failed[*]}" >&2
  echo "  Check 'systemctl status ${failed[0]}' - something may own that path." >&2
  exit 1
fi

echo "Done. This machine will not suspend or hibernate."
echo "  Steam Game Mode's idle timer can still fire - it just fails now."
echo "Test: leave it idle past its usual sleep timeout, then SSH in - it stays up."
echo "Undo: ./no-sleep.sh --revert"

#!/usr/bin/env bash
# ASUS Zephyrus G14 (2025) Ubuntu Setup Script
# Installs ONLY the asus-linux userspace utilities:
#   - asusctl            (keyboard backlight, fan curves, power profile, slash LED)
#   - supergfxctl        (GPU mode switching)
#   - rog-control-center (GUI front-end)
#
# Does NOT touch the kernel and does NOT install audio firmware.
# Target: Ubuntu 26.04 LTS on the 2025 Zephyrus G14.
#
# Reference: ~/origin/g14/setup-g14.sh (Fedora version)
# Upstream:  https://gitlab.com/asus-linux/asusctl
#            https://gitlab.com/asus-linux/supergfxctl
# Notes:     asus-linux.org has no official Ubuntu repo, so we build from source.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

ask() {
    local prompt="$1"
    local response
    while true; do
        read -rp "$(echo -e "${YELLOW}$prompt [Y/n]:${NC} ")" response
        case "$response" in
            ''|[yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    err "This script requires Ubuntu/Debian (apt-get). Exiting."
    exit 1
fi

if ! grep -qiE 'ubuntu|debian' /etc/os-release; then
    warn "/etc/os-release does not look like Ubuntu/Debian. Continue at your own risk."
    ask "Proceed anyway?" || exit 1
fi

BUILD_DIR="${BUILD_DIR:-$HOME/.cache/g14-build}"
mkdir -p "$BUILD_DIR"

echo ""
echo -e "${GREEN}ASUS Zephyrus G14 (2025) Ubuntu Setup${NC}"
echo "Installs asusctl, supergfxctl, rog-control-center from source."
echo "Build artifacts cached in: $BUILD_DIR"
echo ""

# ─────────────────────────────────────────────────────────
# 1. APT update + build dependencies
# ─────────────────────────────────────────────────────────

section "1. Build Dependencies"

if ask "Install build dependencies via apt?"; then
    sudo apt-get update
    # Common build deps for asusctl + supergfxctl + rog-control-center (GTK4 GUI).
    sudo apt-get install -y \
        build-essential \
        curl \
        git \
        pkg-config \
        cmake \
        clang \
        libclang-dev \
        libudev-dev \
        libdbus-1-dev \
        libssl-dev \
        libsystemd-dev \
        libfontconfig1-dev \
        libgtk-4-dev \
        libadwaita-1-dev \
        gettext
    ok "Build dependencies installed."
else
    info "Skipping dependency install — assuming you have them."
fi

# ─────────────────────────────────────────────────────────
# 2. Rust toolchain
# ─────────────────────────────────────────────────────────

section "2. Rust Toolchain"

if command -v cargo &>/dev/null && command -v rustc &>/dev/null; then
    ok "Rust already installed: $(rustc --version)"
else
    if ask "Install Rust via rustup (per-user, ~/.cargo)?"; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
        ok "Rust installed: $(rustc --version)"
    else
        err "Rust is required to build asusctl/supergfxctl. Aborting."
        exit 1
    fi
fi

# Make sure cargo is on PATH for the rest of this script.
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
fi

# ─────────────────────────────────────────────────────────
# 3. asusctl (+ rog-control-center)
# ─────────────────────────────────────────────────────────

section "3. asusctl + rog-control-center"
info "Provides: keyboard backlight, fan curves, power profile, slash LED."

if ask "Build & install asusctl from source?"; then
    cd "$BUILD_DIR"
    if [ -d asusctl/.git ]; then
        info "Updating existing asusctl checkout..."
        git -C asusctl fetch --tags
        git -C asusctl pull --ff-only
    else
        git clone https://gitlab.com/asus-linux/asusctl.git
    fi

    cd asusctl
    info "Building (this takes several minutes)..."
    make
    sudo make install
    ok "asusctl installed."
else
    info "Skipping asusctl build."
fi

# Repair / post-install — runs unconditionally if asusd.service is installed.
# Safe to re-run; idempotent. This is what fixes the common failure modes:
#   - /etc/asusd missing → status=226/NAMESPACE because of ReadWritePaths=
#   - dbus/udev policies dropped after their daemons loaded config
#   - asusd hit StartLimitBurst and is hard-stopped in 'failed' state
if [ -f /usr/lib/systemd/system/asusd.service ]; then
    info "Applying asusd post-install / repair steps..."
    sudo mkdir -p /etc/asusd
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo systemctl reload dbus.service 2>/dev/null || sudo systemctl restart dbus.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed asusd.service 2>/dev/null || true

    info "Starting asusd..."
    if sudo systemctl start asusd.service; then
        ok "asusd started."
    else
        warn "asusd failed to start. Diagnose with:"
        warn "  sudo journalctl -u asusd.service -n 60 --no-pager"
    fi
    info "Try: asusctl --show-supported"
fi

# ─────────────────────────────────────────────────────────
# 4. supergfxctl
# ─────────────────────────────────────────────────────────

section "4. supergfxctl"
info "Provides: GPU mode switching (Hybrid / Integrated / dGPU / Vfio)."

if ask "Build & install supergfxctl from source?"; then
    cd "$BUILD_DIR"
    if [ -d supergfxctl/.git ]; then
        info "Updating existing supergfxctl checkout..."
        git -C supergfxctl fetch --tags
        git -C supergfxctl pull --ff-only
    else
        git clone https://gitlab.com/asus-linux/supergfxctl.git
    fi

    cd supergfxctl
    info "Building..."
    make
    sudo make install
    ok "supergfxctl installed."
else
    info "Skipping supergfxctl build."
fi

# Repair / post-install — runs unconditionally if supergfxd.service is installed.
if [ -f /usr/lib/systemd/system/supergfxd.service ]; then
    info "Applying supergfxd post-install / repair steps..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo systemctl reload dbus.service 2>/dev/null || sudo systemctl restart dbus.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed supergfxd.service 2>/dev/null || true

    if sudo systemctl enable --now supergfxd.service 2>/dev/null; then
        ok "supergfxd enabled and started."
    else
        if sudo systemctl start supergfxd.service; then
            ok "supergfxd started (no [Install] section — D-Bus activated)."
        else
            warn "supergfxd failed to start. Diagnose with:"
            warn "  sudo journalctl -u supergfxd.service -n 60 --no-pager"
        fi
    fi
    info "Try: supergfxctl -g   (show current mode)"
else
    info "Skipping supergfxctl."
fi

# ─────────────────────────────────────────────────────────
# 5. power-profiles-daemon vs tuned
# ─────────────────────────────────────────────────────────

section "5. Power Profile Backend"
info "asusd talks to power-profiles-daemon (Ubuntu default). If 'tuned' is"
info "installed it will fight asusd over the platform profile / CPU EPP."

if systemctl list-unit-files 2>/dev/null | grep -q '^tuned\.service'; then
    if systemctl is-active tuned &>/dev/null || systemctl is-enabled tuned &>/dev/null; then
        if ask "Mask tuned.service so asusctl owns the power profile?"; then
            sudo systemctl mask --now tuned
            ok "tuned masked."
        fi
    else
        ok "tuned present but already inactive."
    fi
else
    ok "tuned not installed — nothing to do."
fi

if ! systemctl is-active power-profiles-daemon &>/dev/null; then
    if ask "Install & enable power-profiles-daemon (recommended)?"; then
        sudo apt-get install -y power-profiles-daemon
        sudo systemctl enable --now power-profiles-daemon
        ok "power-profiles-daemon enabled."
    fi
else
    ok "power-profiles-daemon already active."
fi

# ─────────────────────────────────────────────────────────
# 6. LED Defaults: keyboard + slash
# ─────────────────────────────────────────────────────────

section "6. LED Defaults"
info "Default look: blue keyboard backlight on low brightness, slash LED"
info "as a solid pattern at dim brightness (if firmware supports it)."
info "asusctl persists these in /etc/asusd; they survive reboots."

if ! command -v asusctl &>/dev/null || ! systemctl is-active asusd &>/dev/null; then
    warn "asusctl/asusd not available — skipping LED defaults."
    info "After asusd is up, run manually:"
    info "  asusctl led-mode static -c 0000FF"
    info "  asusctl -k low"
    info "  asusctl slash --enable true && asusctl slash --mode Static && asusctl slash --brightness 77"
elif ask "Apply default LED settings now (blue+low keyboard, solid+dim slash)?"; then

    # ── Keyboard: blue static, low brightness ────────────
    info "Keyboard: static blue, low brightness..."
    if asusctl led-mode static -c 0000FF 2>/dev/null; then
        ok "Keyboard LED mode set to static blue."
    else
        warn "Could not set keyboard LED mode (firmware may not expose 'static')."
    fi
    if asusctl -k low 2>/dev/null; then
        ok "Keyboard brightness set to low."
    else
        warn "Could not set keyboard brightness."
    fi

    # ── Slash: solid pattern, dim brightness ─────────────
    info "Slash: enabled, solid mode, dim brightness..."
    if asusctl slash --enable true 2>/dev/null; then
        ok "Slash LED enabled."
    else
        warn "asusctl slash --enable failed (some 2025 firmwares lack support)."
    fi

    if asusctl slash --mode Static 2>/dev/null; then
        ok "Slash mode set to Static (no animation)."
    else
        warn "Could not set Static mode. Available modes:"
        asusctl slash --list 2>/dev/null | sed 's/^/    /' || true
    fi

    # Brightness is 0–255 in asusctl; 77 ≈ 30%.
    if asusctl slash --brightness 77 2>/dev/null; then
        ok "Slash brightness set to 77/255 (~30%)."
    else
        warn "asusctl slash --brightness failed; trying sysfs fallback."
        if [ -f /sys/class/leds/asus::lightbar/brightness ]; then
            MAX=$(cat /sys/class/leds/asus::lightbar/max_brightness 2>/dev/null || echo 1)
            DIM=$(( MAX / 8 ))
            [ "$DIM" -lt 1 ] && DIM=1
            echo "$DIM" | sudo tee /sys/class/leds/asus::lightbar/brightness >/dev/null
            ok "Lightbar sysfs brightness set to $DIM/$MAX."

            if ask "Persist across reboots (udev rule)?"; then
                sudo tee /etc/udev/rules.d/99-asus-lightbar-dim.rules >/dev/null <<UDEV
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::lightbar", ATTR{brightness}="$DIM"
UDEV
                sudo udevadm control --reload
                ok "Udev rule written to /etc/udev/rules.d/99-asus-lightbar-dim.rules"
            fi
        else
            warn "No /sys/class/leds/asus::lightbar node found either."
            echo "  - Track upstream: https://gitlab.com/asus-linux/asusctl/-/issues/482"
        fi
    fi
else
    info "Skipping LED defaults."
fi

# ─────────────────────────────────────────────────────────
# 7. Verification
# ─────────────────────────────────────────────────────────

section "7. Verification"

echo -n "Kernel:           "; uname -r
echo -n "asusctl:          "; command -v asusctl >/dev/null && asusctl --version 2>/dev/null || echo "not installed"
echo -n "supergfxctl:      "; command -v supergfxctl >/dev/null && supergfxctl --version 2>/dev/null || echo "not installed"
echo -n "rog-control-center:"; command -v rog-control-center >/dev/null && echo " installed" || echo " not installed"
echo -n "asusd service:    "; systemctl is-active asusd 2>/dev/null || echo "inactive"
echo -n "supergfxd service:"; systemctl is-active supergfxd 2>/dev/null || echo "inactive"
echo -n "Slash LED sysfs:  "
if [ -f /sys/class/leds/asus::lightbar/brightness ]; then
    echo "brightness=$(cat /sys/class/leds/asus::lightbar/brightness)"
else
    echo "not present"
fi

section "Done"
echo "Useful commands:"
echo "  asusctl --show-supported       # what hardware controls are exposed"
echo "  asusctl profile -P Quiet       # set platform profile"
echo "  asusctl -k low|med|high|off    # keyboard backlight level"
echo "  asusctl led-mode static -c 0000FF      # keyboard color (blue default)"
echo "  asusctl slash --brightness 77          # slash dim (0-255, ~30%)"
echo "  asusctl slash --mode Static            # slash solid, no animation"
echo "  supergfxctl -m Integrated      # switch GPU mode (logout required)"
echo ""
echo "If asusctl reports the device is not supported, you likely need a newer"
echo "asusctl than what's in upstream main — check the open MRs on GitLab."
echo ""

if ask "Reboot now?"; then
    # -i ignores GNOME/session inhibitors; without it the reboot is blocked
    # whenever a graphical session is open.
    sudo systemctl reboot -i
else
    info "Reboot when you're ready (recommended after first install)."
fi

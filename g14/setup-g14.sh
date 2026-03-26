#!/usr/bin/env bash
# ASUS Zephyrus G14 (2025) Linux Setup Script
# Fixes: lightbar blinking, speaker audio, general hardware support
# Target: Fedora with asus-linux ecosystem
# References:
#   https://asus-linux.org/guides/fedora-guide/
#   https://github.com/wxllow/zephyrus-g14-2025-linux
#   https://gitlab.com/asus-linux/asusctl/-/issues/482

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
        read -rp "$(echo -e "${YELLOW}$prompt [y/n]:${NC} ")" response
        case "$response" in
            [yY]|[yY][eE][sS]) return 0 ;;
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
# Pre-flight checks
# ─────────────────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

if ! command -v dnf &>/dev/null; then
    err "This script requires Fedora (dnf). Exiting."
    exit 1
fi

echo ""
echo -e "${GREEN}ASUS Zephyrus G14 (2025) Linux Setup${NC}"
echo "This script will walk you through setting up hardware support."
echo "Each section can be skipped. A reboot is needed at the end."
echo ""

# ─────────────────────────────────────────────────────────
# 1. System Update
# ─────────────────────────────────────────────────────────

section "1. System Update"

if ask "Update system packages first?"; then
    sudo dnf update -y
    ok "System updated."
else
    info "Skipping system update."
fi

# ─────────────────────────────────────────────────────────
# 2. asus-linux Ecosystem (asusctl, supergfxctl)
# ─────────────────────────────────────────────────────────

section "2. asus-linux Ecosystem"
info "Provides: keyboard backlight, fan curves, power profiles, GPU switching."

if ask "Install asus-linux tools (asusctl, supergfxctl, rog-control-center)?"; then
    # Enable COPR repo if not already enabled
    if ! dnf copr list 2>/dev/null | grep -q "lukenukem/asus-linux"; then
        sudo dnf copr enable -y lukenukem/asus-linux
        ok "COPR repo enabled."
    else
        ok "COPR repo already enabled."
    fi

    sudo dnf install -y asusctl supergfxctl rog-control-center
    sudo systemctl enable --now asusd.service
    sudo systemctl enable --now supergfxd.service

    ok "asus-linux tools installed and services enabled."
    info "Run 'asusctl --show-supported' to see available hardware controls."

    # Mask tuned — it overrides asusctl's platform profile and EPP settings,
    # forcing the CPU governor to 'performance' even when asusctl sets Quiet.
    if systemctl is-active tuned &>/dev/null || systemctl is-enabled tuned &>/dev/null; then
        info "Masking tuned service (conflicts with asusctl power profiles)..."
        sudo systemctl mask --now tuned
        ok "tuned masked. asusctl will manage power profiles."
    else
        ok "tuned already inactive/masked."
    fi
else
    info "Skipping asus-linux tools."
fi

# ─────────────────────────────────────────────────────────
# 3. Lightbar (Slash LED) Control
# ─────────────────────────────────────────────────────────

section "3. Lightbar (Slash LED)"
warn "Lightbar is NOT fully supported by asusd on the 2025 G14 yet."
info "Attempting available workarounds..."

if ask "Try to disable the lightbar?"; then
    LIGHTBAR_FIXED=false

    # Method 1: sysfs
    info "Checking sysfs LED devices..."
    if ls /sys/class/leds/ 2>/dev/null | grep -qi "asus"; then
        echo "Found ASUS LED devices:"
        ls /sys/class/leds/ | grep -i asus
        echo ""
    fi

    if [ -f /sys/class/leds/asus::lightbar/brightness ]; then
        info "Found asus::lightbar sysfs device. Disabling..."
        echo 0 | sudo tee /sys/class/leds/asus::lightbar/brightness >/dev/null
        ok "Lightbar disabled via sysfs."
        LIGHTBAR_FIXED=true

        # Make persistent via udev rule
        if ask "Make this persistent across reboots (udev rule)?"; then
            sudo tee /etc/udev/rules.d/99-asus-lightbar-off.rules >/dev/null <<'UDEV'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::lightbar", ATTR{brightness}="0"
UDEV
            ok "Udev rule created at /etc/udev/rules.d/99-asus-lightbar-off.rules"
        fi
    else
        warn "No asus::lightbar sysfs device found."
    fi

    # Method 2: asusctl slash
    if ! $LIGHTBAR_FIXED && command -v asusctl &>/dev/null; then
        info "Trying asusctl slash commands..."

        if asusctl slash -b 0 2>/dev/null; then
            ok "Lightbar disabled via asusctl slash."
            LIGHTBAR_FIXED=true
        else
            warn "asusctl slash -b 0 failed (expected on 2025 G14)."
        fi

        if ! $LIGHTBAR_FIXED && asusctl slash --enable false 2>/dev/null; then
            ok "Lightbar disabled via asusctl slash --enable false."
            LIGHTBAR_FIXED=true
        else
            warn "asusctl slash --enable false also failed."
        fi
    fi

    if ! $LIGHTBAR_FIXED; then
        warn "Could not disable lightbar from Linux."
        echo ""
        echo "Remaining options:"
        echo "  1. Check BIOS/UEFI for a 'Slash Lighting' toggle"
        echo "  2. Monitor upstream: https://gitlab.com/asus-linux/asusctl/-/issues/482"
        echo "  3. If you have Windows dual-boot, use G-Helper to set it OFF"
        echo "     (the setting persists in EC firmware across reboots)"
        echo ""
    fi
else
    info "Skipping lightbar setup."
fi

# ─────────────────────────────────────────────────────────
# 4. Audio Firmware
# ─────────────────────────────────────────────────────────

section "4. Audio Firmware (CS35L56 Woofer Amplifiers)"
info "The G14 has 4 speakers: 2 tweeters (Realtek) + 2 woofers (Cirrus CS35L56)."
info "The woofers need specific firmware to produce bass."

if ask "Install audio firmware packages?"; then
    sudo dnf install -y linux-firmware alsa-sof-firmware alsa-firmware
    ok "Firmware packages installed."

    # Check for device-specific firmware
    info "Checking for CS35L56 firmware (SSID 10431024)..."
    if ls /lib/firmware/cirrus/ 2>/dev/null | grep -q "10431024"; then
        ok "CS35L56 firmware for this model found."
    else
        warn "CS35L56 firmware for SSID 10431024 not found."

        if ls /lib/firmware/cirrus/ 2>/dev/null | grep -q "10431b13"; then
            info "Found firmware for similar model (10431b13)."
            warn "NOTE: Using firmware from another device is a workaround."
            warn "Avoid max volume to protect speakers until official firmware ships."

            if ask "Create symlinks from 10431b13 firmware?"; then
                cd /lib/firmware/cirrus/

                for file in cs35l56-b0-dsp1-misc-10431b13-spkid0-amp1.bin \
                            cs35l56-b0-dsp1-misc-10431b13-spkid0-amp2.bin \
                            cs35l56-b0-dsp1-misc-10431b13-spkid0.wmfw; do
                    target="${file//10431b13/10431024}"
                    if [ ! -e "$target" ]; then
                        sudo ln -s "$file" "$target"
                        ok "Created symlink: $target -> $file"
                    else
                        info "Already exists: $target"
                    fi
                done

                # Also check for .zst compressed variants
                for file in cs35l56-b0-dsp1-misc-10431b13-spkid0.wmfw.zst; do
                    if [ -f "$file" ]; then
                        target="${file//10431b13/10431024}"
                        if [ ! -e "$target" ]; then
                            sudo ln -s "$file" "$target"
                            ok "Created symlink: $target -> $file"
                        fi
                    fi
                done

                info "Rebuilding initramfs..."
                sudo dracut --force
                ok "Initramfs rebuilt. Firmware will load on next boot."
            fi
        else
            warn "No similar firmware found either."
            warn "You may need to update linux-firmware or extract firmware manually."
            warn "See: https://asus-linux.org/guides/cirrus-amps/"
        fi
    fi
else
    info "Skipping audio firmware."
fi

# ─────────────────────────────────────────────────────────
# 5. CachyOS Kernel
# ─────────────────────────────────────────────────────────

section "5. CachyOS Kernel"
info "The CachyOS kernel includes audio DAC routing fixes for the G14 2025."
info "Without this, the volume slider causes distortion instead of volume change."
warn "This will exclude the stock Fedora kernel from updates."

if ask "Install CachyOS kernel?"; then
    # Exclude stock kernel
    info "Excluding stock kernel from dnf updates..."
    EXCLUDES="kernel,kernel-core,kernel-modules,kernel-uki-virt,kernel-devel,kernel-modules-extra,kernel-modules-core,kernel-devel-matched"
    sudo dnf config-manager setopt "fedora.excludepkgs=$EXCLUDES" 2>/dev/null || true
    sudo dnf config-manager setopt "updates.excludepkgs=$EXCLUDES" 2>/dev/null || true

    # Enable CachyOS COPR
    if ! dnf copr list 2>/dev/null | grep -q "bieszczaders/kernel-cachyos"; then
        sudo dnf copr enable -y bieszczaders/kernel-cachyos
    fi

    sudo dnf install -y kernel-cachyos kernel-cachyos-devel-matched
    ok "CachyOS kernel installed."
    warn "You must reboot to use the new kernel."
else
    info "Skipping CachyOS kernel."
    warn "Speaker audio fix may not work fully without the DAC routing patch."
fi

# ─────────────────────────────────────────────────────────
# 6. PipeWire Soft Mixer
# ─────────────────────────────────────────────────────────

section "6. PipeWire Soft Mixer"
info "This ensures the desktop volume slider controls actual volume"
info "instead of introducing distortion (workaround for DAC routing)."

if ask "Configure PipeWire soft mixer?"; then
    WIREPLUMBER_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
    mkdir -p "$WIREPLUMBER_DIR"

    cat > "$WIREPLUMBER_DIR/50-alsa-softmixer.conf" <<'EOF'
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_output.*" }
    ]
    actions = {
      update-props = {
        api.alsa.soft-mixer = true
      }
    }
  }
]
EOF
    ok "WirePlumber soft mixer config written."
    info "Will take effect after restart or: systemctl --user restart wireplumber"
else
    info "Skipping PipeWire soft mixer config."
fi

# ─────────────────────────────────────────────────────────
# 7. ALSA Amplifier Volume
# ─────────────────────────────────────────────────────────

section "7. ALSA Amplifier Volume"
info "The CS35L56 amplifiers have their own volume controls."
info "These must be set to 0dB for the woofers to produce sound."

if ask "Set CS35L56 amplifier volume to 0dB?"; then
    # Find the CS35L56 card
    CS_CARD=""
    for card_num in 0 1 2 3 4; do
        if amixer -c"$card_num" info 2>/dev/null | grep -qi "cirrus\|cs35l56"; then
            CS_CARD="$card_num"
            break
        fi
        # Also check by trying to access AMP controls
        if amixer -c"$card_num" sget 'AMP1 Speaker' 2>/dev/null | grep -q "dB"; then
            CS_CARD="$card_num"
            break
        fi
    done

    if [ -n "$CS_CARD" ]; then
        info "Found CS35L56 on card $CS_CARD"
        amixer -c"$CS_CARD" sset 'AMP1 Speaker' 0dB 2>/dev/null && ok "AMP1 Speaker set to 0dB" || warn "Could not set AMP1 Speaker"
        amixer -c"$CS_CARD" sset 'AMP2 Speaker' 0dB 2>/dev/null && ok "AMP2 Speaker set to 0dB" || warn "Could not set AMP2 Speaker"
        sudo alsactl store 2>/dev/null && ok "ALSA state saved." || warn "Could not save ALSA state."
    else
        warn "CS35L56 sound card not detected."
        info "This is expected if you haven't rebooted with the new kernel/firmware yet."
        info "After reboot, run manually:"
        echo "  aplay -l | grep -i cirrus"
        echo "  amixer -c<N> sset 'AMP1 Speaker' 0dB"
        echo "  amixer -c<N> sset 'AMP2 Speaker' 0dB"
        echo "  sudo alsactl store"
    fi
else
    info "Skipping amplifier volume setup."
fi

# ─────────────────────────────────────────────────────────
# 8. EasyEffects (Optional Audio Enhancement)
# ─────────────────────────────────────────────────────────

section "8. EasyEffects (Optional)"
info "EasyEffects with ASUS presets improves speaker quality."
info "Linux lacks Dolby Atmos, so this is the closest substitute."

if ask "Install EasyEffects with ASUS G14 presets?"; then
    sudo dnf install -y easyeffects

    if command -v git &>/dev/null; then
        TMPDIR=$(mktemp -d)
        if git clone https://github.com/sammilucia/asus-easyeffects.git "$TMPDIR" 2>/dev/null; then
            mkdir -p "$HOME/.config/easyeffects"
            cp -r "$TMPDIR/easyeffects/"* "$HOME/.config/easyeffects/"
            ok "EasyEffects presets installed to ~/.config/easyeffects/"
            info "Launch EasyEffects, select a preset, and toggle it on."
        else
            warn "Could not clone presets repo. Install presets manually from:"
            echo "  https://github.com/sammilucia/asus-easyeffects"
        fi
        rm -rf "$TMPDIR"
    else
        warn "git not found. Install presets manually from:"
        echo "  https://github.com/sammilucia/asus-easyeffects"
    fi
else
    info "Skipping EasyEffects."
fi

# ─────────────────────────────────────────────────────────
# 9. Verification
# ─────────────────────────────────────────────────────────

section "9. Verification"

info "Running checks..."
echo ""

# Kernel
echo -n "Kernel: "
uname -r

# asusctl
echo -n "asusctl: "
if command -v asusctl &>/dev/null; then
    asusctl --version 2>/dev/null || echo "installed"
else
    echo "not installed"
fi

# supergfxctl
echo -n "supergfxctl: "
if command -v supergfxctl &>/dev/null; then
    supergfxctl --version 2>/dev/null || echo "installed"
else
    echo "not installed"
fi

# CS35L56 firmware
echo -n "CS35L56 firmware (10431024): "
if ls /lib/firmware/cirrus/ 2>/dev/null | grep -q "10431024"; then
    echo "present"
else
    echo "MISSING"
fi

# CS35L56 driver loaded
echo -n "CS35L56 kernel module: "
if lsmod 2>/dev/null | grep -q "cs35l56"; then
    echo "loaded"
else
    echo "not loaded (may need reboot)"
fi

# Lightbar sysfs
echo -n "Lightbar sysfs: "
if [ -f /sys/class/leds/asus::lightbar/brightness ]; then
    echo "available (brightness=$(cat /sys/class/leds/asus::lightbar/brightness))"
else
    echo "not available"
fi

# PipeWire
echo -n "PipeWire soft mixer config: "
if [ -f "$HOME/.config/wireplumber/wireplumber.conf.d/50-alsa-softmixer.conf" ]; then
    echo "present"
else
    echo "not configured"
fi

# EasyEffects
echo -n "EasyEffects: "
if command -v easyeffects &>/dev/null; then
    echo "installed"
else
    echo "not installed"
fi

echo ""

# ─────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────

section "Setup Complete"

echo "Next steps:"
echo "  1. REBOOT to load new kernel and firmware"
echo "  2. After reboot, check firmware: dmesg | grep -i cs35l56"
echo "  3. If speakers still have no bass, set amp volume:"
echo "     aplay -l | grep -i cirrus"
echo "     amixer -c<N> sset 'AMP1 Speaker' 0dB"
echo "     amixer -c<N> sset 'AMP2 Speaker' 0dB"
echo "  4. Check BIOS for lightbar toggle if it's still blinking"
echo ""
echo "Known limitations:"
echo "  - Lightbar may need upstream asusctl fix"
echo "  - Audio won't fully match Windows (no Dolby Atmos)"
echo "  - Headset mic detection is still broken upstream"
echo "  - Speakers may go silent after suspend (reboot fixes it)"
echo ""
echo "Upstream tracking:"
echo "  Lightbar: https://gitlab.com/asus-linux/asusctl/-/issues/482"
echo "  Audio:    https://asus-linux.org/guides/cirrus-amps/"
echo ""

if ask "Reboot now?"; then
    sudo reboot
else
    info "Remember to reboot when ready."
fi

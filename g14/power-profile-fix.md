# Power Profile Fix: tuned vs asusctl Conflict

## Problem

On battery, the CPU governor was stuck on `performance` and the ASUS platform profile wouldn't switch to `Quiet`, wasting battery life.

**Root cause:** The `tuned` service (set to `throughput-performance`) was overriding `asusctl`'s platform profile and EPP settings. Even when `asusctl profile set Quiet` was run, `tuned` would immediately force the CPU governor back to `performance` and lock the available EPP to `[Performance]` only.

## Symptoms

- `asusctl profile get` shows `Quiet` but CPU governor stays `performance`
- `tuned-adm active` shows `throughput-performance`
- asusd logs show `Available EPP: [Performance]` (should list multiple options)
- Battery drains faster than expected

## Fix

1. **Mask the tuned service** so it can't interfere with asusctl:
   ```bash
   sudo systemctl mask --now tuned
   ```

2. **Set the power profile via asusctl:**
   ```bash
   asusctl profile set Quiet
   ```

3. **Verify:**
   ```bash
   asusctl profile get                    # Should show: Active profile: Quiet
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # Should show: powersave
   cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference  # Should show: balance_performance or power
   systemctl is-active tuned              # Should show: inactive
   ```

## Additional Notes

- The `setup-g14.sh` script was updated to mask `tuned` automatically after installing asus-linux tools.
- `asusctl` is configured to auto-switch profiles: `Performance` on AC, `Quiet` on battery.
- The NVIDIA GPU in Hybrid mode will suspend on its own after a few minutes of idle. For maximum battery savings, switch to Integrated mode via ROG Control Center or `supergfxctl -m Integrated` (requires logout).
- If `tuned` comes back after a system update, re-mask it: `sudo systemctl mask --now tuned`

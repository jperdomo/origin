# NixOS Configuration

NixOS system configuration for host `origin`, running Hyprland on Wayland.

## Structure

```
nixos/
├── flake.nix                    # Flake entry point
├── configuration.nix            # Main system config
├── hardware-configuration.nix   # Hardware/disk/boot detection
└── modules/
    ├── user.nix                 # User account (jperdomo)
    ├── networking.nix           # NetworkManager + firewall
    └── desktop.nix              # Hyprland, greetd, PipeWire, fonts, desktop apps
```

## Files

- **flake.nix** — Defines a single NixOS configuration called `origin`, targeting `x86_64-linux`, tracking `nixos-unstable`.

- **configuration.nix** — Main config that imports the three modules. Sets up systemd-boot, timezone (America/New_York), locale, allows unfree packages, and installs base CLI tools (git, gh, curl, htop, gcc, etc.).

- **hardware-configuration.nix** — Placeholder hardware config. Disk labels (`nixos` for `/`, `boot` for `/boot`) and kernel modules are set, but this should be regenerated on the actual machine with `nixos-generate-config`.

- **modules/user.nix** — Creates user `jperdomo` with wheel, networkmanager, video, audio, and input groups.

- **modules/networking.nix** — Enables NetworkManager and the firewall.

- **modules/desktop.nix** — Full Hyprland Wayland desktop stack: greetd + tuigreet login manager, PipeWire audio, polkit, hyprlock, and desktop apps (kitty, wofi, waybar, firefox, Thunar, etc.).

## Deploying

### First-time install

1. Install NixOS (minimal ISO is fine)
2. Clone this repo onto the machine
3. Regenerate the hardware config for the actual hardware:
   ```bash
   sudo nixos-generate-config --show-hardware-config > nixos/hardware-configuration.nix
   ```
4. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake /path/to/origin/nixos#origin
   ```

### Ongoing updates

After making changes to the config:

```bash
sudo nixos-rebuild switch --flake /path/to/origin/nixos#origin
```

### Dry run

Apply the config without adding it to the bootloader (reboot reverts):

```bash
sudo nixos-rebuild test --flake /path/to/origin/nixos#origin
```

## Notes

- **hardware-configuration.nix is a placeholder** — regenerate it on the target machine before deploying, otherwise disk labels and kernel modules may not match.
- **No flake.lock yet** — the first `nixos-rebuild` will generate one. Commit it afterward.
- **x86_64-linux only** — this config won't build on macOS or ARM systems.

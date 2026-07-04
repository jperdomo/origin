# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- `bazzite/configure-bazzite.sh`: grouped two-phase TUI configurator for a fresh Bazzite install (pick sections, then toggle items per section); idempotent, re-runnable, with a `NO_TUI` numbered fallback. Options: brave, ptyxis, perf, dboost, asus, lighting, m4key, virt, cockpit, ollama, theme, kde-dark, nmtui
- G14 asusctl setup: `g14/asusd-deploy.sh` (deploy the asusd root daemon on atomic Bazzite, since the brew cask postflight can't sudo), `g14/lighting.sh` + `g14/lighting-service.sh` (slash solid/dimmed + keyboard colour, re-applied at login), `g14/m4-bind.sh` (bind the M4 key / XF86Launch1 to ROG Control Center)
- `bazzite/kde-macos-theme.sh` + helpers (`kde-remove-full-bottom-panel.py`, `kde-remove-mac-panels.py`, `kde-dock-launchers.py`, `pin-to-dock.sh`): WhiteSur macOS look applied non-destructively (no `--resetLayout`) with a native top bar + floating dock, persistent panel edits (stop plasmashell → edit config → restart), and lock-screen wallpaper sync
- `bazzite/kde-default-dark.sh`: revert to stock KDE Breeze Dark and the default bottom-bar layout, preserving pinned apps and the Bazzite launcher logo
- Ptyxis terminal setup (via `configure-bazzite.sh`): rpm-ostree layer (reboot), set as default terminal, dark, and first in the dock
- `wg-rsync/` directory: generic file-transfer harness over containerized WireGuard with SSH bootstrap, multi-path batching, and `.env` configuration
- NixOS declarative system configuration (flake) with Hyprland desktop
- `.claude/` to .gitignore for Claude Code local settings
- Zed editor settings sync with symlink installer
- MIT LICENSE file
- .gitignore entries for #archive/, editor files, .vscode/, .idea/, Thumbs.db
- `set -e` to all scripts (exit on error)
- `.gitattributes` for line ending normalization

### Changed
- g14/setup-g14.sh: rewrite the asusctl section for atomic Bazzite (brew casks + `asusd-deploy.sh`, not dnf/COPR); asusd owns the platform profile so tuned/tuned-ppd are masked
- bazzite/ollama-podman.sh: make idempotent (start the existing container instead of erroring if it already exists)
- Enable NVIDIA Dynamic Boost (`nvidia-powerd`) via the `dboost` option — fixes the RTX 5070 Ti mobile pinned at 180 MHz under load on the G14
- Reorganize .gitignore with categories and add .env and Excel temp file exclusions
- Update mac/basics-mac.sh: add zed, remove monitorcontrol/utm/webstorm/TickTick, clean up dead code
- win/install-winget.ps1: ExecutionPolicy Unrestricted → RemoteSigned
- bazzite/ollama-podman.sh: bind port 11434 to 127.0.0.1 instead of 0.0.0.0
- Standardize all root checks to use `$EUID` instead of `whoami`/`$UID`
- tailscale/tailscale-routing.sh: interactive subnet input instead of hardcoded values
- Rename dockge/dockage-deploy.sh → dockge-deploy.sh (typo fix)

### Fixed
- Fix unicode en-dash in proxmox/nvidia-proxmox-drivers-container-toolkit.sh (command was silently failing)
- Quote variables in git/git-setup.sh, debian/sudo-user.sh, debian/user-add.sh
- Quote hostnames in ubuntu/hostname-set.sh, rhel/hostname-set.sh
- Hide token input in ubuntu/livepatch.sh (read -rs)
- tailscale/tailscale-rocky.sh: `wait 3` → `sleep 3`
- bazzite/cockpit-bazzite.sh: `mkdir` → `mkdir -p`
- rhel/media-codecs.sh: add missing `-y` flag to `dnf install`
- debian/flatpak-install.sh: fix "Flatak" typo

### Removed
- Remove others/ directory (Firefox profile, misc scripts, selector)
- Remove mac/#archive/ directory (contained hardcoded personal info)
- Remove rclone/ directory (hardcoded personal paths)
- Remove rsync/ directory (hardcoded IP, example script)
- Remove rhel/virt-user_reset.sh (hardcoded username, broken sudo redirect)
- Remove ubuntu/gnome-extensions.sh (both implementations broken)
- Remove mac/office-install.sh commented-out dead code
- Remove REVIEW.md (all items resolved)

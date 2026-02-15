# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- MIT LICENSE file
- .gitignore entries for #archive/, editor files, .vscode/, .idea/, Thumbs.db
- `set -e` to all scripts (exit on error)
- `.gitattributes` for line ending normalization

### Changed
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

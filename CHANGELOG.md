# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- MIT LICENSE file
- .gitignore entries for .mozilla/ and REVIEW.md

### Changed
- Reorganize .gitignore with categories and add .env and Excel temp file exclusions
- Update mac/basics-mac.sh: add zed, remove monitorcontrol/utm/webstorm/TickTick, clean up dead code

### Fixed
- Fix unicode en-dash in proxmox/nvidia-proxmox-drivers-container-toolkit.sh (command was silently failing)

### Removed
- Remove others/mozilla/ directory (Firefox profile with credentials)
- Remove others/mnt-nfs-BROKEN.sh (broken script)
- Remove mac/#archive/ directory (contained hardcoded personal info)
- Remove rhel/virt-user_reset.sh (hardcoded username, broken sudo redirect)

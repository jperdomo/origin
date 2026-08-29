# Origin

A collection of shell scripts and automation tools for setting up and configuring various operating systems, services, and environments.

## Quick Start

Clone the repo and run any script directly:

```bash
git clone <repo-url> origin
cd origin
bash ubuntu/basics-ubuntu.sh
```

Most scripts are standalone and can be executed individually. A few are orchestrators that dispatch sibling scripts — see `bazzite/configure-bazzite.sh` and `g14/setup-g14-ubuntu.sh`.

## Directory Structure

| Directory    | Description                                      |
|--------------|--------------------------------------------------|
| `alpine/`    | Alpine Linux setup scripts                       |
| `bazzite/`   | Bazzite (Fedora Atomic) configuration            |
| `debian/`    | Debian server and desktop utilities              |
| `flatpak/`   | Flatpak and Flathub setup                        |
| `g14/`       | ASUS Zephyrus G14 setup and lighting scripts     |
| `gh/`        | GitHub CLI utilities                             |
| `git/`       | Git configuration scripts                        |
| `mac/`       | macOS configuration                              |
| `nixos/`     | NixOS declarative system configuration (flake)   |
| `proxmox/`   | Proxmox VE cluster and LXC utilities             |
| `rhel/`      | RHEL/Fedora setup scripts                        |
| `synology/`  | Synology NAS fixes and utilities                 |
| `tailscale/` | Tailscale VPN setup                              |
| `ubuntu/`    | Ubuntu server and desktop setup                  |
| `wg-rsync/`  | File transfer over containerized WireGuard tunnel|
| `win/`       | Windows PowerShell setup scripts                 |
| `zed/`       | Zed editor settings sync                         |

## Requirements

- Bash 4+ (or PowerShell for Windows scripts)
- Root/sudo access for most scripts

## License

[MIT](LICENSE)

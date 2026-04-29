# wg-rsync

Generic file transfer over a containerized WireGuard tunnel. Run from the
**destination** host. Self-contained: `setup.sh` bootstraps the entire
WireGuard link and SSH plumbing into `./state/`; `wg-rsync.sh` runs deploys
that orchestrate a single `--rm` container on the source running `wg-quick up`
+ `rsync` over the tunnel.

Distilled from a one-off NAS migration pattern that pushed 1.7 TB at ~14 MB/s.

## Quickstart

    cd ~/origin/wg-rsync
    ./setup.sh                   # one-time: prompts, generates keys, brings up wg0
    cp .env.example .env
    $EDITOR .env                 # set SRC_PATHS and DST_DIR
    ./wg-rsync.sh                # deploy

Or fully via env, no `.env`:

    SRC_PATHS=/volume2/Media/TV,/volume2/Media/Movies \
    DST_DIR=/mnt/media \
    ./wg-rsync.sh

Or positional paths:

    ./wg-rsync.sh /volume2/Media/TV /volume2/Media/Movies

## What `setup.sh` does (one-time)

1. apt-installs `wireguard` on destination if missing (sudo)
2. Generates server + client WG keypairs in `./state/wg/`
3. Auto-detects destination's public IP and LAN IP
4. Renders `./state/wg/wg-server.conf` and `./state/wg/wg-client.conf`;
   installs the server conf to `/etc/wireguard/$WG_IFACE.conf` (sudo, with
   diff-prompt if an existing conf is in the way)
5. **Pauses** for you to add a UDP port-forward on your router/modem (prints
   the exact rule)
6. `sudo wg-quick up $WG_IFACE` and adds idempotent iptables INPUT rules for
   UDP/$WG_PORT and `-i $WG_IFACE`
7. Generates an in-container SSH keypair in `./state/ssh/`; appends the
   pubkey to `~/.ssh/authorized_keys` with a `# wg-rsync setup` marker so
   the in-container rsync can SSH back to destination
8. Pushes the WG client config + the SSH private key to the source via
   sshpass (prompts for the source SSH password and saves it 0600 to
   `./state/src-ssh-pwd` for subsequent runs)

Idempotent: re-run safely — existing keys/configs are reused.

## What `wg-rsync.sh` does (per deploy)

| Phase | What happens |
|-------|--------------|
| 0/5 Preflight | Verify WG iface up, asymmetric routing sanity check, `state/` artifacts present, SSH probe |
| 1/5 Bootstrap | Discover container engine on source; sha256-compare and push WG conf + SSH key (idempotent); build image if missing |
| 2/5 Listing | `rsync -a --list-only` over SSH on source; push items list back to source |
| 3/5 Spawn | `docker/podman run --rm` on source: `wg-quick up wg0`, then `rsync` to `$DST_USER@$WG_DST_ADDR:$DST_DIR/<basename>/` |
| 4/5 Progress | Poll `du -sb` on destination every 10s; print throughput + ETA |
| 5/5 Cleanup | Wait, log final stats, remove items list. Loop next path. |

For multiple `SRC_PATHS`, phases 2-5 run sequentially per path; bootstrap
runs once.

## State layout

Everything `setup.sh` generates lives under `./state/` (gitignored):

    state/
    ├── network.env              # PUBLIC_IP, LAN_IP, WG_PORT, SRC_USER, SRC_HOST, ...
    ├── src-ssh-pwd              # 0600, source SSH password
    ├── ssh/
    │   ├── src-key              # 0600, in-container SSH private key
    │   └── src-key.pub          # appended to dest's ~/.ssh/authorized_keys
    └── wg/
        ├── server.{key,pub}     # 0600 / 0644
        ├── client.{key,pub}
        ├── wg-server.conf       # source-of-truth for /etc/wireguard/$WG_IFACE.conf
        └── wg-client.conf       # pushed to source

`wg-rsync.sh` reads `state/network.env` automatically, so after setup you
typically only need `SRC_PATHS` and `DST_DIR` in your `.env`.

## Configuration

See `.env.example`. Most knobs only need to be set if you're overriding
something `setup.sh` baked into `state/network.env`. The ones you'll usually
touch:

| Var | Default | Notes |
|-----|---------|-------|
| `SRC_PATHS` | (prompted) | Comma-separated absolute paths on source |
| `DST_DIR` | (prompted) | Destination root; each path -> `$DST_DIR/<basename>/` |
| `DST_USER` | `$USER` | User the in-container rsync ssh-es as |
| `EXCLUDES` | `@eaDir,#recycle,.DS_Store,Thumbs.db` | Comma-separated rsync excludes |
| `RSYNC_FLAGS` | (sane defaults) | Verbatim rsync flags |
| `LOG_DIR` | `$HOME/wg-rsync-logs` | Per-path log files |
| `FORCE_BOOTSTRAP` | `0` | `1` to re-push conf/key + rebuild image |
| `DRY_RUN` | `0` | `1` to print intended commands and exit |

## Prerequisites

- Bash 4+ on destination, `wg`/`wg-quick` installed (setup.sh installs if
  missing), plus `ssh rsync awk find du stat ip curl ssh-keygen sha256sum
  flock sed sshpass`
- Source has Docker or Podman; root or rootless OK (set `ENGINE_SUDO=sudo`
  if rootful)
- Source has internet egress on first run (apt + Docker Hub) so the helper
  image can be built. Subsequent runs reuse the cached image.
- A working router/modem port-forward for UDP/`$WG_PORT` (you set this
  during `setup.sh`)

## Tear down

    sudo wg-quick down $WG_IFACE                     # default wg0
    sudo rm /etc/wireguard/$WG_IFACE.conf
    # remove the '# wg-rsync setup' block from ~/.ssh/authorized_keys
    rm -rf state/

On the source: remove the pushed conf and key:

    ssh source 'rm -f /tmp/wg-rsync-client.conf /tmp/wg-rsync-key'
    ssh source 'docker rmi wg-rsync:latest'          # or podman

## Troubleshooting

**Listings hang or rsync stalls** — usually MTU on the WG path. Try clamping
TCP MSS on the destination:

    sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
        -j TCPMSS --clamp-mss-to-pmtu

**"asymmetric routing"** — the script's reply path to the source's public IP
goes through a different interface than your default route. Common with
libvirt or LXC bridges. Add a host route via your default gateway:

    sudo ip route add <SRC_PUBLIC_IP>/32 via <gateway> dev <iface>

**"image build failed"** — source needs internet egress on first run. If
that's not possible, build on a workstation and ship the image:

    docker build -t wg-rsync:latest .
    docker save wg-rsync:latest | ssh source 'docker load'

**`gained: 0.00 B` non-zero exit** — benign WG-userspace teardown race;
treated as success and the script continues to the next path.

**"another wg-rsync.sh instance is running"** — flock at
`/tmp/wg-rsync.lock`. If a previous run died uncleanly, remove the lock.

## What's intentionally not here

- Tailscale support — earlier benchmarks topped out at ~4.5 MB/s vs WG's
  ~14 MB/s. WG-only here.
- Parallel rsync streams — the WG link is the bottleneck; serial is simpler.
- WG conf scaffolding from somewhere other than `setup.sh`. If you have an
  existing WG link you want to reuse, drop your wg-server.conf and
  wg-client.conf into `state/wg/` and skip step 4 of setup.

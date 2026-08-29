#!/bin/bash
set -e

echo "Installing Tailscale..."
TS_INSTALLER=$(mktemp)
trap 'rm -f "$TS_INSTALLER"' EXIT
curl -fsSL https://tailscale.com/install.sh -o "$TS_INSTALLER"
echo "805e85ed6f6f81a7ea2e70d52d47e7d5290863299e5c922b2787d71aa312f22e  $TS_INSTALLER" | sha256sum -c - >/dev/null
sh "$TS_INSTALLER"

echo ""
echo -n "Enter your Tailscale auth key (leave blank to authenticate manually later): "
read -r -s TS_AUTHKEY
echo ""

if [ -z "$TS_AUTHKEY" ]; then
    echo "No auth key provided. Run 'sudo tailscale up' to authenticate."
    exit 0
fi

echo -n "Accept subnet routes from other nodes? (y/n): "
read -r ACCEPT_ROUTES

# Pass the auth key via env var, not --authkey= on the command line
# (argv is world-readable via /proc/<pid>/cmdline).
TS_ARGS="--accept-dns"
if [[ "$ACCEPT_ROUTES" =~ ^[Yy]$ ]]; then
    TS_ARGS="$TS_ARGS --accept-routes"
fi

# shellcheck disable=SC2086
TS_AUTHKEY="$TS_AUTHKEY" sudo -E tailscale up $TS_ARGS

echo ""
tailscale status

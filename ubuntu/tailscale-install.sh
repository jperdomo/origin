#!/bin/bash
set -e

echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

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

TS_ARGS="--authkey=${TS_AUTHKEY} --accept-dns"
if [[ "$ACCEPT_ROUTES" =~ ^[Yy]$ ]]; then
    TS_ARGS="$TS_ARGS --accept-routes"
fi

# shellcheck disable=SC2086
sudo tailscale up $TS_ARGS

echo ""
tailscale status

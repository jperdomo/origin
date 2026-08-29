#!/bin/bash
set -e

TS_INSTALLER=$(mktemp)
trap 'rm -f "$TS_INSTALLER"' EXIT
curl -fsSL https://tailscale.com/install.sh -o "$TS_INSTALLER"
echo "805e85ed6f6f81a7ea2e70d52d47e7d5290863299e5c922b2787d71aa312f22e  $TS_INSTALLER" | sha256sum -c - >/dev/null
sh "$TS_INSTALLER"
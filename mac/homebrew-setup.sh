#!/bin/sh
set -e
BREW_INSTALLER=$(mktemp)
trap 'rm -f "$BREW_INSTALLER"' EXIT
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$BREW_INSTALLER"
echo "12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41  $BREW_INSTALLER" | sha256sum -c - >/dev/null
/bin/bash "$BREW_INSTALLER"
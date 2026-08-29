#!/bin/bash
set -e

echo "Installing Claude Code..."
CLAUDE_INSTALLER=$(mktemp)
trap 'rm -f "$CLAUDE_INSTALLER"' EXIT
curl -fsSL https://claude.ai/install.sh -o "$CLAUDE_INSTALLER"
echo "3a68d3406cf674e17bed1733a4dcf37805e2e47d87417700007d7e1aa766a944  $CLAUDE_INSTALLER" | sha256sum -c - >/dev/null
bash "$CLAUDE_INSTALLER"

echo ""
echo "Claude Code installed. Run 'claude' to get started."

#!/bin/bash
set -e

key="$HOME/.ssh/id_ed25519"

read -r -p "Email for SSH key comment: " email
ssh-keygen -t ed25519 -C "$email" -f "$key"

echo
echo "Public key:"
cat "$key.pub"

echo
echo "Add it at: https://github.com/settings/keys"
echo "  Title: anything you want"
echo "  Type:  Authentication Key"
echo
read -r -p "Press Enter once added on GitHub..."

read -r -p "GitHub username: " gh_user
echo
echo "Fetching https://github.com/$gh_user.keys ..."
echo
keys=$(curl -sSf "https://github.com/$gh_user.keys")
echo "$keys"

key_body=$(awk '{print $2}' "$key.pub")
echo
if grep -qF "$key_body" <<< "$keys"; then
    echo "Confirmed: this key is published on GitHub."
else
    echo "Not yet visible. If you just added it, retry in a few seconds."
fi

#!/bin/bash
set -e

#Username
echo Github Organization?
read org

gh repo list "$org" --limit 4000 | while read -r repo _; do   gh repo clone "$repo" "$repo"; done
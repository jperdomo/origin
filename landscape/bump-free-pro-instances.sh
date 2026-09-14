#!/bin/bash
# bump-free-pro-instances.sh — raise the hardcoded MAX_FREE_PRO_INSTANCES cap.
#
# Why: the standalone free-personal Pro license covers unlimited VMs, but
# Landscape hardcodes MAX_FREE_PRO_INSTANCES = 5 in the installed module, so a
# VM fleet beyond 5 hosts fails Accept with "Licensing this instance would
# exceed the limit of 5 Free Ubuntu Pro instances".
#
# Run as root ON THE LANDSCAPE SERVER. Bumped to 100 on 2026-09-14 (fleet is
# 12 hosts; 100 clears any near-term growth). Package upgrades of
# landscape-server-quickstart rewrite this file back to 5 — re-run after every
# upgrade. Backups are kept as .bak-20260914* alongside the file.
set -u

SP=/opt/venvs/landscape/lib/python3.12/site-packages/canonical/landscape/model/main/licensing_strategies.py
TARGET="${MAX_FREE_PRO_INSTANCES:-100}"

[ -f "$SP" ] || { echo "module not found: $SP" >&2; exit 1; }

grep -q "^MAX_FREE_PRO_INSTANCES = $TARGET$" "$SP" && {
  echo "already set to $TARGET; nothing to do"
  exit 0
}

cp "$SP" "${SP}.bak-$(date +%Y%m%d)"
sed -i "s/^MAX_FREE_PRO_INSTANCES = [0-9]*$/MAX_FREE_PRO_INSTANCES = $TARGET/" "$SP"

/opt/venvs/landscape/bin/python3 -c \
  "import canonical.landscape.model.main.licensing_strategies as m; print(m.__file__, m.MAX_FREE_PRO_INSTANCES)" || {
  echo "python import check failed" >&2; exit 1; }

systemctl restart landscape-api landscape-appserver landscape-msgserver landscape-job-handler
sleep 4
systemctl is-active landscape-api landscape-appserver landscape-msgserver landscape-job-handler
echo "OK: cap is $TARGET, services restarted."

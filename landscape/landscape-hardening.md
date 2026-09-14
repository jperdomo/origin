# Landscape hardening (2026-09-13)

Fixes applied to the self-hosted Landscape fleet to collapse lifecycle-command latency.

## What was wrong

1. **Ping fast path never wired on TLS.** The quickstart's port-80 vhost had
   `RewriteRule ^/ping$ http://localhost:8070/ping [P]` but the port-443 vhost
   (where clients actually ping) did not — every HTTPS ping 404'd into the
   appserver, so clients never got "messages waiting" nudges and pickup fell to
   the 15-minute exchange grid.
2. **Fixed 120s shutdown delay** hardcoded in the client's shutdownmanager
   (success ack is sent before the delay, so cutting it is safe).
3. **No exchange-interval fallback**: if the fast path ever breaks again,
   15-minute pickup returns with no safety net.

## Server (landscape.alpine-typhon.ts.net)

- `/etc/apache2/sites-enabled/landscape.alpine-typhon.ts.net.conf` (443 vhost):
  added `RewriteRule ^/ping$ http://localhost:8070/ping [P,L]`, `apachectl
  configtest`, `systemctl reload apache2`.
- Verify: client ping returns 200 through pingserver (access log), pingserver
  logs the 200, no `NotFound: name: 'ping'` tracebacks.

## Client (per managed host)

Run as root on the client:

```bash
bash /opt/data/scripts/landscape-client-harden.sh
```

- Appends `exchange_interval = 300` to `/etc/landscape/client.conf`
  (burst insurance behind the ping fast path).
- `sed` the client's shutdownmanager: `shutdown_delay=120` -> `shutdown_delay=10`.
- Restarts landscape-client, prints the three verified values.

Note: the delay patch sits in the installed package and is overwritten on the
next landscape-client upgrade — re-run the script after upgrades.

Offline boxes (gamma-tech, media, gamma-metrc-backup): run it on disk via
`pct mount` / guest agent at next boot, or from the running system.

## Licensing (seat exhaustion and the free-Pro cap)

A standalone account licenses by seat. A computer accepted while the legacy
pool is full (or before Pro was attached) lands UNLICENSED: no Shutdown/Reboot
buttons, OS reads "---". Fix per host WITHOUT re-registering — attach Pro, drop
the pro-info data-watcher persist, restart the client (see
`landscape-license-roll.sh`, run as root on the client). The unlicensed message
set deliberately includes `ubuntu-pro-info`; the server's
`update_pro_licensing` handler re-classifies on the next send.

The free-personal Pro tier covers unlimited VMs, but Landscape hardcodes
`MAX_FREE_PRO_INSTANCES = 5` (site-packages
`canonical/landscape/model/main/licensing_strategies.py`), so a 6th accept
fails in the portal. Cap is 100 now — re-run `bump-free-pro-instances.sh`
after any `landscape-server-quickstart` upgrade (the package rewrites the
module). The server code also lives at `/opt/canonical/landscape/...` — the
live copy is the venv site-packages one; edit the venv file, not the
/opt/canonical clone.

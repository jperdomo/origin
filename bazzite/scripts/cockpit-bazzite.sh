#!/usr/bin/env bash
#
# cockpit-bazzite.sh - Cockpit web console on Bazzite, the containerized way.
#
# Bazzite is rpm-ostree, so cockpit isn't layered, and the 'ujust setup-cockpit'
# recipe this script was originally pasted from has since been dropped from the
# image (there is no cockpit recipe left in /usr/share/ublue-os/just). Instead we
# run the official cockpit-ws container, which is what cockpit-project.org/running
# documents for immutable hosts.
#
# Two consequences of the container path that are easy to get wrong:
#
#   1. The RUN label publishes no port. The container is --privileged and setns()es
#      into the HOST net + uts namespaces, so cockpit-ws binds :9090 on the host
#      directly. Podman therefore never touches firewalld for us the way it would
#      for a -p mapping, and without the explicit firewall-cmd below the console is
#      silently localhost-only. (Upstream's recipe omitted this.)
#   2. Cockpit authenticates web logins by SSHing back into the host, so SSH
#      password auth is a hard prerequisite -- see the sshd block. This loosens how
#      the host is reachable; that is deliberate and matches upstream.
#
# RUN internally calls label-install, which writes /etc/systemd/system/cockpit.service
# onto the host. The explicit INSTALL below is thus redundant on podman, but it is
# idempotent and matches the documented order, so we keep it.
#
# Run as your desktop user (it sudos where needed).
# Usage:  ./cockpit-bazzite.sh             install + enable -> https://localhost:9090
#         ./cockpit-bazzite.sh --disable   stop + disable (certs and settings kept)

set -euo pipefail

IMAGE="quay.io/cockpit/ws"

# --- disable -----------------------------------------------------------------
if [[ "${1:-}" == "--disable" ]]; then
  if ! systemctl cat cockpit.service >/dev/null 2>&1; then
    echo "Cockpit is not installed; nothing to disable."
    exit 0
  fi
  echo "Disabling Cockpit"
  # --now, so the running container goes away too; a bare 'disable' would leave
  # cockpit-ws serving :9090 until the next reboot.
  sudo systemctl disable --now cockpit.service
  echo "Cockpit disabled. Re-enable with: ./cockpit-bazzite.sh"
  exit 0
fi

# --- preflight ---------------------------------------------------------------
# label-install refuses to install over a host cockpit-ws and exits 1 with a
# message you'd never see through runlabel. Catch it here with a real hint.
if [[ -f /usr/libexec/cockpit-ws ]]; then
  echo "cockpit-ws is installed on the host (rpm-ostree layered?)." >&2
  echo "The container refuses to install over it. Use the host package instead:" >&2
  echo "  sudo systemctl enable --now cockpit.socket" >&2
  exit 1
fi

# --- idempotency -------------------------------------------------------------
# Mirrors the 'cockpit)' probe in configure-bazzite.sh's item_done(), so the menu
# marker and this early-out can never disagree.
if systemctl is-enabled --quiet cockpit.service 2>/dev/null; then
  echo "Cockpit already enabled; starting it if stopped."
  sudo systemctl start cockpit.service || true
  echo "Cockpit -> https://localhost:9090"
  exit 0
fi

# --- SSH password auth -------------------------------------------------------
# cockpit-ws runs with --local-ssh: the web login is an SSH login against this
# host, so password auth must be on or :9090 will reject your password.
echo "Enabling SSH password authentication (required for Cockpit logins)"
echo 'PasswordAuthentication yes' | sudo tee /etc/ssh/sshd_config.d/02-enable-passwords.conf >/dev/null
sudo systemctl try-restart sshd
sudo systemctl enable --now sshd

# --- pull + run --------------------------------------------------------------
echo "Starting cockpit-ws container (this pulls $IMAGE on first run)"
sudo podman container runlabel --name cockpit-ws RUN "$IMAGE"
sudo podman container runlabel INSTALL "$IMAGE"

# --- pcp metrics (optional) --------------------------------------------------
# Upstream ran these unconditionally. pcp is NOT in the Bazzite image: there is no
# pmlogger unit and no 'pcp' user, so chown pcp:pcp fails with "invalid user" and
# set -e would abort the whole install. Skip cleanly instead.
if systemctl cat pmlogger.service >/dev/null 2>&1; then
  echo "Enabling pmlogger (PCP metrics)"
  sudo mkdir -p /var/lib/pcp/tmp /var/log/pcp/pmlogger
  sudo chown -R pcp:pcp /var/lib/pcp
  sudo chown pcp:pcp /var/log/pcp/pmlogger
  sudo systemctl enable --now pmlogger
else
  echo "pcp/pmlogger not present (normal on Bazzite); skipping."
  echo "  Cockpit's Metrics page will be unavailable. Everything else works."
fi

# --- enable on boot ----------------------------------------------------------
# daemon-reload because label-install wrote the unit behind systemd's back.
echo "Enabling cockpit.service on boot"
sudo systemctl daemon-reload
sudo systemctl enable cockpit.service

# --- firewall ----------------------------------------------------------------
# See the header: the container binds :9090 inside the host netns, so nothing
# opened the port for us. Without this, remote access fails with no clear cause.
if systemctl is-active --quiet firewalld 2>/dev/null; then
  echo "Opening port 9090 in firewalld"
  sudo firewall-cmd --permanent --add-service=cockpit >/dev/null
  sudo firewall-cmd --reload >/dev/null
fi

echo ""
echo "Done! Cockpit is up:"
echo "  Local:   https://localhost:9090"
echo "  Remote:  https://$(hostname):9090   (or your Tailscale IP)"
echo ""
echo "  Log in as '${USER}' with your normal account password (not an SSH key)."
echo "  The cert is self-signed, so the browser warns once; accept it."
echo "  Disable with: ./cockpit-bazzite.sh --disable"

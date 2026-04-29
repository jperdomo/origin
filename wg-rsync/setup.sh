#!/bin/bash
# setup.sh -- one-time bootstrap for wg-rsync.
#   1) install wireguard-tools on destination (sudo, only if missing)
#   2) generate WG server+client keypairs in ./state/wg/
#   3) detect destination's public + LAN IPs
#   4) render server + client wg.conf, install server conf to /etc/wireguard/
#   5) print port-forward instructions and pause
#   6) bring up the WG interface and add iptables rules
#   7) generate an in-container SSH key in ./state/ssh/, append pub to ~/.ssh/authorized_keys
#   8) push client config + SSH key to source via sshpass
#
# Idempotent: re-run safely; existing keys/configs are reused.
# All persistent state lives under ./state/ (gitignored). The only file outside
# the folder we touch is /etc/wireguard/$WG_IFACE.conf (rendered from state) and
# one block appended to ~/.ssh/authorized_keys (marked for easy removal).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
WG_DIR="$STATE_DIR/wg"
SSH_DIR="$STATE_DIR/ssh"
NET_ENV="$STATE_DIR/network.env"
PWFILE="$STATE_DIR/src-ssh-pwd"

WG_IFACE="${WG_IFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_SERVER_ADDR="${WG_SERVER_ADDR:-10.99.0.1}"
WG_CLIENT_ADDR="${WG_CLIENT_ADDR:-10.99.0.2}"
SRC_USER="${SRC_USER:-}"
SRC_HOST="${SRC_HOST:-}"
SRC_PORT="${SRC_PORT:-22}"
WG_CLIENT_CONF_REMOTE="${WG_CLIENT_CONF_REMOTE:-/tmp/wg-rsync-client.conf}"
SRC_SSH_KEY_REMOTE="${SRC_SSH_KEY_REMOTE:-/tmp/wg-rsync-key}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf '[%s] ERR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { err "$*"; exit 1; }
banner() {
    printf '\n================================================================\n'
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
    printf '================================================================\n'
}

mkdir -p "$WG_DIR" "$SSH_DIR"
chmod 700 "$STATE_DIR" "$WG_DIR" "$SSH_DIR"

require_tools() {
    local missing=()
    local t
    for t in ssh ssh-keygen sshpass curl ip awk sed; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]}"
}

prompt_src() {
    if [[ -z "$SRC_USER" ]]; then read -rp "SRC_USER (ssh user on source): " SRC_USER; fi
    if [[ -z "$SRC_HOST" ]]; then read -rp "SRC_HOST (ssh address of source): " SRC_HOST; fi
    [[ -n "$SRC_USER" && -n "$SRC_HOST" ]] || die "SRC_USER and SRC_HOST required"
}

prompt_password() {
    if [[ ! -r "$PWFILE" ]]; then
        log "no source SSH password file at $PWFILE"
        local pw
        read -rsp "  source SSH password (will be saved 0600): " pw
        echo
        ( umask 077; printf '%s' "$pw" >"$PWFILE" )
        log "  saved $PWFILE"
    else
        log "  reusing $PWFILE"
    fi
}

src_ssh() {
    SSHPASS=$(<"$PWFILE") sshpass -e ssh \
        -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=20 \
        -p "$SRC_PORT" "$SRC_USER@$SRC_HOST" "$@"
}

# ---- [1/8] WireGuard tools on destination ---------------------------------

banner "[1/8] WireGuard tools on destination"
if ! command -v wg >/dev/null 2>&1 || ! command -v wg-quick >/dev/null 2>&1; then
    log "  installing wireguard (sudo)"
    sudo apt-get update -qq
    sudo apt-get install -y -qq wireguard
fi
log "  $(wg --version 2>&1 | head -1)"

require_tools
prompt_src
prompt_password

# ---- [2/8] WG keypairs ----------------------------------------------------

banner "[2/8] WG keypairs in $WG_DIR"
if [[ ! -f "$WG_DIR/server.key" ]]; then
    ( umask 077; wg genkey >"$WG_DIR/server.key" )
    wg pubkey <"$WG_DIR/server.key" >"$WG_DIR/server.pub"
    log "  generated server keypair"
else
    log "  server keypair: present"
fi
if [[ ! -f "$WG_DIR/client.key" ]]; then
    ( umask 077; wg genkey >"$WG_DIR/client.key" )
    wg pubkey <"$WG_DIR/client.key" >"$WG_DIR/client.pub"
    log "  generated client keypair"
else
    log "  client keypair: present"
fi

SERVER_PRIV=$(<"$WG_DIR/server.key")
SERVER_PUB=$(<"$WG_DIR/server.pub")
CLIENT_PRIV=$(<"$WG_DIR/client.key")
CLIENT_PUB=$(<"$WG_DIR/client.pub")

# ---- [3/8] Network identities --------------------------------------------

banner "[3/8] Network identities"
PUBLIC_IP="${PUBLIC_IP:-}"
if [[ -z "$PUBLIC_IP" ]]; then
    PUBLIC_IP=$(curl -fsS --max-time 10 https://ifconfig.me 2>/dev/null \
        || curl -fsS --max-time 10 https://ipinfo.io/ip 2>/dev/null \
        || curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null \
        || echo "")
fi
[[ -n "$PUBLIC_IP" ]] || read -rp "  could not auto-detect public IP. Enter destination's public IP: " PUBLIC_IP
log "  public IP : $PUBLIC_IP"

LAN_IP="${LAN_IP:-}"
if [[ -z "$LAN_IP" ]]; then
    LAN_IP=$(ip -4 addr show \
        | awk '/inet / && !/127\./ && !/100\./ && !/192\.168\.123\./ {print $2; exit}' \
        | cut -d/ -f1)
fi
if [[ -z "$LAN_IP" ]]; then
    log "  candidate interfaces:"
    ip -4 addr show | awk '/inet / && !/127\./ {printf "    %-20s on %s\n", $2, $NF}'
    read -rp "  could not auto-pick LAN IP. Enter the one to port-forward TO: " LAN_IP
fi
log "  LAN IP    : $LAN_IP  (port-forward target)"
log "  WG tunnel : server $WG_SERVER_ADDR  client $WG_CLIENT_ADDR  port $WG_PORT iface $WG_IFACE"

cat >"$NET_ENV" <<EOF
PUBLIC_IP=$PUBLIC_IP
LAN_IP=$LAN_IP
WG_PORT=$WG_PORT
WG_IFACE=$WG_IFACE
WG_SERVER_ADDR=$WG_SERVER_ADDR
WG_CLIENT_ADDR=$WG_CLIENT_ADDR
SRC_USER=$SRC_USER
SRC_HOST=$SRC_HOST
SRC_PORT=$SRC_PORT
EOF
chmod 600 "$NET_ENV"
log "  saved $NET_ENV"

# ---- [4/8] Render WG configs ---------------------------------------------

banner "[4/8] Rendering WG configs"
cat >"$WG_DIR/wg-server.conf" <<EOF
[Interface]
Address = $WG_SERVER_ADDR/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $WG_CLIENT_ADDR/32
EOF
chmod 600 "$WG_DIR/wg-server.conf"

cat >"$WG_DIR/wg-client.conf" <<EOF
[Interface]
Address = $WG_CLIENT_ADDR/24
PrivateKey = $CLIENT_PRIV

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = $WG_SERVER_ADDR/32
PersistentKeepalive = 25
EOF
chmod 600 "$WG_DIR/wg-client.conf"
log "  $WG_DIR/wg-server.conf and wg-client.conf written"

SYSCONF="/etc/wireguard/$WG_IFACE.conf"
log "installing server conf to $SYSCONF (sudo)"
if sudo test -f "$SYSCONF" && ! sudo cmp -s "$WG_DIR/wg-server.conf" "$SYSCONF"; then
    log "  WARN: $SYSCONF differs from $WG_DIR/wg-server.conf"
    read -rp "  overwrite? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] || die "aborted; remove or move $SYSCONF and re-run"
fi
sudo install -m 600 -o root -g root "$WG_DIR/wg-server.conf" "$SYSCONF"
log "  installed"

# ---- [5/8] Port-forward (manual) -----------------------------------------

banner "[5/8] *** PORT-FORWARD REQUIRED ***"
cat <<EOF

  Open your router/modem admin UI in a browser and add this rule:

      Service / Name : wg-rsync (anything)
      Protocol       : UDP
      External port  : $WG_PORT
      Internal IP    : $LAN_IP
      Internal port  : $WG_PORT

  Most modems apply changes immediately on save.

EOF
read -rp "  Press ENTER once the port-forward is in place: " _

# ---- [6/8] Bring up wg + iptables ----------------------------------------

banner "[6/8] Bringing $WG_IFACE up (sudo)"
if sudo wg show "$WG_IFACE" >/dev/null 2>&1; then
    log "  $WG_IFACE already up; tearing down to apply current config"
    sudo wg-quick down "$WG_IFACE" 2>/dev/null || true
fi
sudo wg-quick up "$WG_IFACE"
log "  $WG_IFACE status:"
sudo wg show "$WG_IFACE" | sed 's/^/    /'

log "  iptables rules (idempotent)"
sudo iptables -C INPUT -p udp --dport "$WG_PORT" -j ACCEPT 2>/dev/null \
    || sudo iptables -I INPUT -p udp --dport "$WG_PORT" -j ACCEPT
sudo iptables -C INPUT -i "$WG_IFACE" -j ACCEPT 2>/dev/null \
    || sudo iptables -I INPUT -i "$WG_IFACE" -j ACCEPT

# ---- [7/8] In-container SSH key ------------------------------------------

banner "[7/8] In-container SSH key"
SRC_KEY="$SSH_DIR/src-key"
if [[ ! -f "$SRC_KEY" ]]; then
    ssh-keygen -t ed25519 -N '' -f "$SRC_KEY" -C "wg-rsync@$(hostname)" >/dev/null
    log "  generated $SRC_KEY"
else
    log "  reusing $SRC_KEY"
fi
chmod 600 "$SRC_KEY"

AUTH_KEYS="$HOME/.ssh/authorized_keys"
PUBKEY="$(cat "$SRC_KEY.pub")"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
if grep -qF "$PUBKEY" "$AUTH_KEYS"; then
    log "  pubkey already in $AUTH_KEYS"
else
    {
        echo ""
        echo "# wg-rsync setup -- in-container rsync key (remove this and next line to revoke)"
        echo "$PUBKEY"
    } >>"$AUTH_KEYS"
    log "  appended pubkey to $AUTH_KEYS (marker: '# wg-rsync setup')"
fi

# ---- [8/8] Push client config + SSH key to source ------------------------

banner "[8/8] Pushing client config + SSH key to source $SRC_USER@$SRC_HOST"
src_ssh "umask 077; cat > '$WG_CLIENT_CONF_REMOTE'" <"$WG_DIR/wg-client.conf"
log "  pushed $WG_CLIENT_CONF_REMOTE"
src_ssh "umask 077; cat > '$SRC_SSH_KEY_REMOTE'" <"$SRC_KEY"
log "  pushed $SRC_SSH_KEY_REMOTE"

banner "Setup complete"
cat <<EOF
State lives in $STATE_DIR (gitignored).

Next: ./wg-rsync.sh to start a deploy.

To tear down later:
  sudo wg-quick down $WG_IFACE
  sudo rm $SYSCONF
  # remove the '# wg-rsync setup' block from $AUTH_KEYS
  rm -rf $STATE_DIR
EOF

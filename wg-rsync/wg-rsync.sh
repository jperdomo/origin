#!/bin/bash
# wg-rsync.sh -- generic file transfer over a containerized WireGuard tunnel.
#                Run from destination. Bootstraps WG conf + SSH key + container
#                image on source on first run (idempotent). Multi-path batching.
#
# Usage:
#   wg-rsync.sh [-n|--dry-run] [-f|--force-bootstrap] [-e|--env FILE] [-h] [SRC_PATH ...]
#
# Configuration: see .env.example next to this script. Precedence (low->high):
#   defaults -> $SCRIPT_DIR/.env -> $PWD/.env -> --env FILEs -> environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="${WG_RSYNC_LOCK:-/tmp/wg-rsync.lock}"

CLI_PATHS=()
EXTRA_ENV_FILES=()
USED_SLUGS=()
CONTAINER_NAMES=()
RSYNC_PIDS=()
HEARTBEAT_PID=""
ENGINE_DETECTED=""
ENGINE_FULL=""

# ---- helpers ---------------------------------------------------------------

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf '[%s] ERR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { err "$*"; exit 1; }

banner() {
    printf '\n================================================================\n'
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
    printf '================================================================\n'
}

human_bytes() {
    awk -v b="$1" 'BEGIN{
        split("B KB MB GB TB", u); i=1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf "%.2f %s", b, u[i]
    }'
}

slugify() {
    local s="${1,,}"
    s=$(printf '%s' "$s" | sed -E 's#[^a-z0-9._-]+#-#g; s#^-+##; s#-+$##')
    [[ -n "$s" ]] || s="path"
    printf '%s' "$s"
}

require_tools() {
    local missing=()
    local t
    for t in ssh rsync awk find du stat ip curl ssh-keygen sha256sum flock sed; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if [[ -n "${SRC_SSH_PWFILE:-}" ]]; then
        command -v sshpass >/dev/null 2>&1 || missing+=("sshpass")
    fi
    ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]}"
}

load_env_file() {
    local f="$1"
    [[ -r "$f" ]] || return 0
    log "loading env from $f"
    local line key
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        key="${key// /}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        if [[ -z "${!key+x}" ]]; then
            eval "export $line"
        fi
    done <"$f"
}

apply_defaults() {
    : "${SRC_PORT:=22}"
    : "${SRC_SSH_OPTS:=-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=20}"
    : "${SRC_SSH_PWFILE:=$SCRIPT_DIR/state/src-ssh-pwd}"
    : "${WG_IFACE:=wg0}"
    : "${WG_DST_ADDR:=10.99.0.1}"
    : "${WG_CLIENT_CONF:=$SCRIPT_DIR/state/wg/wg-client.conf}"
    : "${WG_CLIENT_CONF_REMOTE:=/tmp/wg-rsync-client.conf}"
    : "${SRC_SSH_KEY:=$SCRIPT_DIR/state/ssh/src-key}"
    : "${SRC_SSH_KEY_REMOTE:=/tmp/wg-rsync-key}"
    : "${DST_USER:=$USER}"
    : "${IMAGE:=wg-rsync:latest}"
    : "${ENGINE_SUDO:=}"
    : "${CONTAINER_NAME_PREFIX:=wg-rsync}"
    : "${LOG_DIR:=$HOME/wg-rsync-logs}"
    : "${EXCLUDES:=@eaDir,#recycle,.DS_Store,Thumbs.db}"
    : "${RSYNC_FLAGS:=-ahr --partial --partial-dir=.rsync-partial --info=stats2,progress2 --human-readable --timeout=600}"
    : "${HEARTBEAT_INTERVAL:=30}"
    : "${PROGRESS_INTERVAL:=10}"
    : "${FORCE_BOOTSTRAP:=0}"
    : "${DRY_RUN:=0}"
    : "${SKIP_AUTHKEY_CHECK:=0}"
    : "${BUCKET_DIR_REMOTE:=/tmp}"
}

prompt_missing() {
    if [[ -z "${SRC_USER:-}" ]]; then
        read -rp "SRC_USER (ssh user on source): " SRC_USER
    fi
    if [[ -z "${SRC_HOST:-}" ]]; then
        read -rp "SRC_HOST (ssh address of source): " SRC_HOST
    fi
    if [[ -z "${SRC_PATHS:-}" && ${#CLI_PATHS[@]} -eq 0 ]]; then
        echo "Enter SRC_PATHS as a comma-separated list of absolute paths on source."
        read -rp "SRC_PATHS: " SRC_PATHS
    fi
    if [[ -z "${DST_DIR:-}" ]]; then
        read -rp "DST_DIR (destination root on this host): " DST_DIR
    fi
    [[ -n "${SRC_USER:-}" ]] || die "SRC_USER required"
    [[ -n "${SRC_HOST:-}" ]] || die "SRC_HOST required"
    [[ -n "${DST_DIR:-}" ]] || die "DST_DIR required"
}

src_ssh() {
    if [[ -n "${SRC_SSH_PWFILE:-}" && -r "$SRC_SSH_PWFILE" ]]; then
        SSHPASS=$(<"$SRC_SSH_PWFILE") sshpass -e ssh \
            -p "$SRC_PORT" \
            $SRC_SSH_OPTS \
            "$SRC_USER@$SRC_HOST" "$@"
    else
        ssh -p "$SRC_PORT" $SRC_SSH_OPTS "$SRC_USER@$SRC_HOST" "$@"
    fi
}

# ---- argv parsing ----------------------------------------------------------

usage() {
    cat <<EOF
Usage: $0 [options] [SRC_PATH ...]

Options:
  -n, --dry-run            print intended container + rsync commands; skip transfer
  -f, --force-bootstrap    re-push conf/key and rebuild image on source
  -e, --env FILE           additional .env to source (highest priority among files)
  -h, --help               show usage

Precedence (high to low): pre-set env, --env FILEs, \$PWD/.env, \$SCRIPT_DIR/.env,
state/network.env (set by ./setup.sh), built-in defaults.
Positional SRC_PATHs override the SRC_PATHS env var.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n | --dry-run) DRY_RUN=1; shift ;;
            -f | --force-bootstrap) FORCE_BOOTSTRAP=1; shift ;;
            -e | --env) EXTRA_ENV_FILES+=("$2"); shift 2 ;;
            -h | --help) usage; exit 0 ;;
            --) shift; CLI_PATHS+=("$@"); break ;;
            -*) die "unknown option: $1" ;;
            *) CLI_PATHS+=("$1"); shift ;;
        esac
    done
}

# ---- preflight -------------------------------------------------------------

preflight() {
    banner "[0/5] Preflight (destination)"
    require_tools

    log "checking WG interface $WG_IFACE on destination"
    if ! sudo wg show "$WG_IFACE" >/dev/null 2>&1; then
        die "$WG_IFACE not up on destination. Try: sudo systemctl start wg-quick@$WG_IFACE"
    fi
    log "  $WG_IFACE: up"

    if [[ -z "${SRC_PUBLIC_IP:-}" ]]; then
        SRC_PUBLIC_IP="$(curl -fsS --max-time 10 https://ifconfig.me 2>/dev/null || true)"
    fi
    if [[ -n "${SRC_PUBLIC_IP:-}" ]]; then
        local reply_iface default_iface
        reply_iface=$(ip route get "$SRC_PUBLIC_IP" 2>/dev/null \
            | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
        default_iface=$(ip route get 1.1.1.1 2>/dev/null \
            | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
        if [[ -z "$reply_iface" ]]; then
            die "no route to source public IP $SRC_PUBLIC_IP -- check connectivity"
        fi
        if [[ "$reply_iface" != "$default_iface" ]]; then
            log "WARN: reply path to $SRC_PUBLIC_IP via '$reply_iface' (default '$default_iface')"
            log "      asymmetric routing may break the WG handshake; investigate if listings hang"
        else
            log "  reply path: $reply_iface"
        fi
    else
        log "  (skipped routing check; no SRC_PUBLIC_IP and ifconfig.me unreachable)"
    fi

    [[ -r "$WG_CLIENT_CONF" ]] || die "WG_CLIENT_CONF not found: $WG_CLIENT_CONF
Run ./setup.sh first."
    [[ -r "$SRC_SSH_KEY" ]] || die "SRC_SSH_KEY not found: $SRC_SSH_KEY
Run ./setup.sh first."
    [[ -r "${SRC_SSH_KEY}.pub" ]] || die "SRC_SSH_KEY public half not found: ${SRC_SSH_KEY}.pub
Run ./setup.sh first."

    if [[ "$SKIP_AUTHKEY_CHECK" != "1" && -r "$HOME/.ssh/authorized_keys" ]]; then
        local pubfp
        pubfp=$(ssh-keygen -lf "${SRC_SSH_KEY}.pub" 2>/dev/null | awk '{print $2}')
        if [[ -n "$pubfp" ]] && ! ssh-keygen -lf "$HOME/.ssh/authorized_keys" 2>/dev/null \
            | awk '{print $2}' | grep -qxF "$pubfp"; then
            die "${SRC_SSH_KEY}.pub fingerprint not found in $HOME/.ssh/authorized_keys
Add it: cat ${SRC_SSH_KEY}.pub >> ~/.ssh/authorized_keys
Or set SKIP_AUTHKEY_CHECK=1 to bypass."
        fi
    fi

    log "probing source $SRC_USER@$SRC_HOST:$SRC_PORT"
    src_ssh true || die "cannot ssh to source"
    log "  source reachable"
}

# ---- bootstrap -------------------------------------------------------------

discover_engine() {
    if [[ -n "${ENGINE:-}" ]]; then
        ENGINE_DETECTED="$ENGINE"
    else
        ENGINE_DETECTED=$(src_ssh '
            for p in docker /usr/local/bin/docker /var/packages/ContainerManager/target/usr/bin/docker podman /usr/bin/podman; do
                if command -v "$p" >/dev/null 2>&1; then echo "$p"; exit 0; fi
                if [ -x "$p" ]; then echo "$p"; exit 0; fi
            done
            exit 1
        ' 2>/dev/null) || true
        [[ -n "$ENGINE_DETECTED" ]] || die "no container engine found on source. Set ENGINE=path."
    fi
    if [[ -n "$ENGINE_SUDO" ]]; then
        ENGINE_FULL="$ENGINE_SUDO $ENGINE_DETECTED"
    else
        ENGINE_FULL="$ENGINE_DETECTED"
    fi
    log "engine on source: $ENGINE_FULL"
}

remote_sha256() {
    src_ssh "sha256sum '$1' 2>/dev/null | cut -d' ' -f1" 2>/dev/null || true
}

push_if_differs() {
    local local_path="$1"
    local remote_path="$2"
    local local_hash remote_hash
    local_hash=$(sha256sum "$local_path" | cut -d' ' -f1)
    remote_hash=$(remote_sha256 "$remote_path")
    if [[ "$FORCE_BOOTSTRAP" == "1" || "$local_hash" != "$remote_hash" ]]; then
        log "  pushing $local_path -> source:$remote_path"
        src_ssh "umask 077; cat > '$remote_path'" <"$local_path"
    else
        log "  $remote_path: up-to-date"
    fi
}

bootstrap() {
    banner "[1/5] Bootstrap (source, idempotent)"
    discover_engine

    log "WG client conf:"
    push_if_differs "$WG_CLIENT_CONF" "$WG_CLIENT_CONF_REMOTE"

    log "SSH key:"
    push_if_differs "$SRC_SSH_KEY" "$SRC_SSH_KEY_REMOTE"

    log "container image $IMAGE:"
    if [[ "$FORCE_BOOTSTRAP" == "1" ]] \
        || ! src_ssh "$ENGINE_FULL image inspect $IMAGE >/dev/null 2>&1"; then
        local dockerfile="$SCRIPT_DIR/Dockerfile"
        [[ -r "$dockerfile" ]] || die "Dockerfile not found at $dockerfile"
        log "  building (one-time, ~2 min)"
        if ! src_ssh "$ENGINE_FULL build -t $IMAGE -" <"$dockerfile" 2>&1 \
            | sed 's/^/    /'; then
            die "image build failed"
        fi
        log "  built; sanity-check:"
        src_ssh "$ENGINE_FULL run --rm $IMAGE sh -c 'rsync --version | head -1; wg --version 2>&1 | head -1'" \
            | sed 's/^/    /'
    else
        log "  present"
    fi
}

# ---- per-path transfer -----------------------------------------------------

build_excludes_args() {
    local IFS=','
    local out=""
    local x
    for x in $EXCLUDES; do
        out+=" --exclude=$x"
    done
    printf '%s' "$out"
}

start_heartbeat() {
    (
        while sleep "$HEARTBEAT_INTERVAL"; do
            local sz
            sz=$(du -sh "$DST_DIR" 2>/dev/null | awk '{print $1}')
            printf '[%s] *heartbeat* dst=%s\n' "$(date +%H:%M:%S)" "${sz:-0}"
        done
    ) &
    HEARTBEAT_PID=$!
}

stop_heartbeat() {
    if [[ -n "$HEARTBEAT_PID" ]]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
        HEARTBEAT_PID=""
    fi
}

cleanup() {
    local rc=$?
    stop_heartbeat
    if [[ -n "$ENGINE_FULL" ]]; then
        local cn
        for cn in "${CONTAINER_NAMES[@]}"; do
            src_ssh "$ENGINE_FULL rm -f $cn >/dev/null 2>&1" || true
        done
    fi
    local pid
    for pid in "${RSYNC_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    exit "$rc"
}

list_source_path() {
    local src_path="$1"
    local listing
    if ! listing=$(src_ssh "rsync -a --list-only '$src_path/' 2>&1"); then
        err "  listing failed:"
        printf '%s\n' "$listing" | sed 's/^/    /' >&2
        return 1
    fi
    # Parse rsync --list-only output. Format:
    #   drwxr-xr-x         4,096 2025/04/26 12:34:56 ItemName
    # Use sed to strip the perms/size/date/time prefix; keeps multi-space names.
    printf '%s\n' "$listing" \
        | awk '/^[d-]/' \
        | sed -E 's|^[^ ]+ +[0-9,]+ +[0-9/]+ +[0-9:]+ +||' \
        | awk 'NF > 0 && $0 != "." && $0 != ".."'
}

transfer_path() {
    local src_path="$1"
    local base
    base="$(basename "$src_path")"
    local slug
    slug="$(slugify "$base")"
    local final_slug="$slug"
    local suffix=0
    while [[ ${#USED_SLUGS[@]} -gt 0 ]] && printf '%s\n' "${USED_SLUGS[@]}" | grep -qxF "$final_slug"; do
        suffix=$((suffix + 1))
        final_slug="${slug}-${suffix}"
    done
    USED_SLUGS+=("$final_slug")

    local dst_subdir="$DST_DIR/$base"
    local cname="${CONTAINER_NAME_PREFIX}-${final_slug}"
    local bucket="$BUCKET_DIR_REMOTE/wg-rsync-items-${final_slug}.txt"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local logfile="$LOG_DIR/${final_slug}-${ts}.log"

    banner "$base ($src_path -> $dst_subdir)"
    mkdir -p "$dst_subdir"

    local already_present
    already_present=$(du -sb "$dst_subdir" 2>/dev/null | awk '{print $1+0}')
    log "  destination has $(human_bytes "$already_present") already"

    log "[2/5] listing $src_path via rsync over SSH"
    local items
    items=$(list_source_path "$src_path") || return 1
    local item_count
    item_count=$(printf '%s\n' "$items" | grep -c '^.\+$' || true)
    if (( item_count == 0 )); then
        log "  no items found"
        return 0
    fi
    log "  found $item_count top-level items"
    log "  pushing items list to $SRC_HOST:$bucket"
    printf '%s\n' "$items" | src_ssh "umask 077; cat > '$bucket'"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "[3/5] DRY_RUN=1: would spawn container $cname"
        log "  rsync target inside container: $DST_USER@$WG_DST_ADDR:$dst_subdir/"
        log "  excludes: $(build_excludes_args)"
        log "  rsync flags: $RSYNC_FLAGS"
        src_ssh "rm -f '$bucket'" || true
        return 0
    fi

    local excludes_args
    excludes_args=$(build_excludes_args)

    src_ssh "$ENGINE_FULL rm -f $cname >/dev/null 2>&1" || true
    CONTAINER_NAMES+=("$cname")

    log "[3/5] spawning container $cname; log -> $logfile"

    (
        src_ssh "$ENGINE_FULL run --rm \
            --name $cname \
            --hostname $cname \
            --cap-add NET_ADMIN \
            --device /dev/net/tun \
            -v $src_path:/media:ro \
            -v $SRC_SSH_KEY_REMOTE:/root/.ssh/id_ed25519:ro \
            -v $WG_CLIENT_CONF_REMOTE:/etc/wireguard/wg0.conf:ro \
            -v $bucket:/items.txt:ro \
            -e DEBIAN_FRONTEND=noninteractive \
            -e UBUNTU_USER=$DST_USER \
            -e WG_SERVER_ADDR=$WG_DST_ADDR \
            -e DST_DIR='$dst_subdir' \
            --entrypoint bash \
            $IMAGE \
            -c '
                set -e
                export WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go
                wg-quick up wg0 2>&1 | sed \"s/^/  [wg-up] /\"
                sleep 2
                ping -c 1 -W 5 \$WG_SERVER_ADDR >/dev/null 2>&1 || { echo \"  WG tunnel down\"; exit 7; }
                echo \"  [container] WG tunnel up; starting rsync\"
                mkdir -p /root/.ssh-rw
                cp /root/.ssh/id_ed25519 /root/.ssh-rw/id_ed25519
                chmod 600 /root/.ssh-rw/id_ed25519
                rsync $RSYNC_FLAGS $excludes_args \
                    --files-from=/items.txt \
                    -e \"ssh -i /root/.ssh-rw/id_ed25519 -o UserKnownHostsFile=/tmp/known_hosts -o StrictHostKeyChecking=accept-new\" \
                    /media/ \
                    \$UBUNTU_USER@\$WG_SERVER_ADDR:\$DST_DIR/
            '" >"$logfile" 2>&1
    ) &
    local pid=$!
    RSYNC_PIDS+=("$pid")
    log "  pid=$pid"

    log "[4/5] live progress (poll every ${PROGRESS_INTERVAL}s)"
    local start_ts last_ts last_size now total elapsed gained avg_mbps inst_secs inst_mbps
    start_ts=$(date +%s)
    last_ts=$start_ts
    last_size=$already_present
    while kill -0 "$pid" 2>/dev/null; do
        sleep "$PROGRESS_INTERVAL"
        now=$(date +%s)
        total=$(du -sb "$dst_subdir" 2>/dev/null | awk '{print $1+0}')
        elapsed=$((now - start_ts))
        gained=$((total - already_present))
        if (( elapsed > 0 && gained > 0 )); then
            avg_mbps=$(awk -v g="$gained" -v e="$elapsed" 'BEGIN{ printf "%.2f", g/e/1048576 }')
        else
            avg_mbps="0.00"
        fi
        inst_secs=$((now - last_ts))
        if (( inst_secs > 0 )); then
            inst_mbps=$(awk -v g="$((total - last_size))" -v s="$inst_secs" 'BEGIN{ printf "%.2f", g/s/1048576 }')
        else
            inst_mbps="0.00"
        fi
        printf '[%s]   gained %s  total %s  inst %s MB/s  avg %s MB/s\n' \
            "$(date +%H:%M:%S)" \
            "$(human_bytes "$gained")" \
            "$(human_bytes "$total")" \
            "$inst_mbps" "$avg_mbps"
        last_ts=$now
        last_size=$total
    done

    log "[5/5] cleanup"
    set +e
    wait "$pid"
    local rc=$?
    set -e

    src_ssh "rm -f '$bucket'" || true
    local final
    final=$(du -sb "$dst_subdir" 2>/dev/null | awk '{print $1+0}')
    gained=$((final - already_present))
    log "  exit=$rc  final=$(human_bytes "$final")  gained this run: $(human_bytes "$gained")"

    if (( rc != 0 )); then
        if (( gained == 0 )); then
            log "  WARN: rc=$rc but gained 0 B -- treating as benign WG-teardown race"
            return 0
        fi
        err "  $base: rc=$rc; aborting run. Re-run to retry/resume."
        return "$rc"
    fi
    return 0
}

# ---- main ------------------------------------------------------------------

main() {
    parse_args "$@"

    # Precedence (load_env_file sets only if unset, so first set wins):
    #   pre-set env > --env files > $PWD/.env > $SCRIPT_DIR/.env > state/network.env > defaults
    local f
    for f in "${EXTRA_ENV_FILES[@]}"; do
        load_env_file "$f"
    done
    if [[ "$PWD" != "$SCRIPT_DIR" ]]; then
        load_env_file "$PWD/.env"
    fi
    load_env_file "$SCRIPT_DIR/.env"
    load_env_file "$SCRIPT_DIR/state/network.env"

    apply_defaults
    prompt_missing

    mkdir -p "$LOG_DIR"

    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        die "another wg-rsync.sh instance is running (lock: $LOCK_FILE)"
    fi

    trap cleanup EXIT INT TERM

    preflight
    bootstrap

    local paths=()
    if (( ${#CLI_PATHS[@]} > 0 )); then
        paths=("${CLI_PATHS[@]}")
    else
        IFS=',' read -r -a paths <<<"$SRC_PATHS"
    fi
    (( ${#paths[@]} > 0 )) || die "no source paths to transfer"

    local p b
    local seen_bases=()
    for p in "${paths[@]}"; do
        b="$(basename "$p")"
        local s
        for s in "${seen_bases[@]:-}"; do
            if [[ -n "$s" && "$s" == "$b" ]]; then
                die "duplicate destination basename '$b' from path '$p' (paths map to \$DST_DIR/<basename>/; v1 disallows collisions)"
            fi
        done
        seen_bases+=("$b")
    done

    start_heartbeat
    local overall_start
    overall_start=$(date +%s)

    for p in "${paths[@]}"; do
        transfer_path "$p"
    done

    stop_heartbeat
    local overall_end
    overall_end=$(date +%s)
    banner "ALL PATHS DONE -- total $((overall_end - overall_start))s"
}

main "$@"

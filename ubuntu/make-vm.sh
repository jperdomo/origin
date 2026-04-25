#!/usr/bin/env bash
# make-vm.sh — create an unattended Ubuntu 26.04 VM via libvirt + cloud-init NoCloud seed.
# Usage:   make-vm.sh [-y|--yes] [--desktop|--server] [--rdp|--no-rdp] [--passwordless-sudo] [--user NAME] [--memory MB] [--vcpus N] [--disk GB] [VM_NAME]
# Default: interactive — prompts for every setting (any flags you pass become the prefilled defaults).
#          server, 2 vCPU, 4 GiB RAM, 40 GiB disk, user = $USER.
# --rdp (desktop only): install gnome-remote-desktop and enable system-level Remote Login
#          on port 3389 with same username/password as the user account.
# --passwordless-sudo: grant the created user NOPASSWD sudo (off by default).
# After install, a background watcher detaches the install + seed CDROMs and deletes
# the seed ISO (use --keep-cdrom to skip). Watcher log: $XDG_STATE_HOME/make-vm/<name>-cleanup.log
# -y skips prompts (requires VM_NAME on cmdline; password from MAKEVM_PASSWORD env var).

set -euo pipefail

VARIANT=server
USERNAME=$USER
MEM_MB=4096
VCPUS=2
DISK_GB=40
NAME=
INTERACTIVE=1
RDP=0
KEEP_CDROM=0
PASSWORDLESS_SUDO=0
IMG_DIR=/var/lib/libvirt/images

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes|--non-interactive) INTERACTIVE=0; shift;;
        -i|--interactive) INTERACTIVE=1; shift;;
        --desktop) VARIANT=desktop; shift;;
        --server)  VARIANT=server;  shift;;
        --rdp)     RDP=1; shift;;
        --no-rdp)  RDP=0; shift;;
        --keep-cdrom) KEEP_CDROM=1; shift;;
        --passwordless-sudo) PASSWORDLESS_SUDO=1; shift;;
        --user)    USERNAME=$2; shift 2;;
        --memory)  MEM_MB=$2;   shift 2;;
        --vcpus)   VCPUS=$2;    shift 2;;
        --disk)    DISK_GB=$2;  shift 2;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \?//'; exit 0;;
        -*)        echo "unknown flag: $1" >&2; exit 2;;
        *)         NAME=$1; shift;;
    esac
done

[[ -t 0 ]] || INTERACTIVE=0

ask() {
    local var=$1 def=$2 msg=$3 val
    read -rp "$msg [$def]: " val
    printf -v "$var" '%s' "${val:-$def}"
}

ask_yn() {
    local var=$1 def=$2 msg=$3 val def_label
    [[ $def == 1 ]] && def_label=Y/n || def_label=y/N
    read -rp "$msg [$def_label]: " val
    val=${val:-$([[ $def == 1 ]] && echo y || echo n)}
    case $val in
        y|Y|yes|YES|1) printf -v "$var" '%s' 1;;
        *)             printf -v "$var" '%s' 0;;
    esac
}

if (( INTERACTIVE )); then
    while :; do
        ask VARIANT  "$VARIANT"  "Variant (server/desktop)"
        [[ $VARIANT == server || $VARIANT == desktop ]] && break
        echo "  must be 'server' or 'desktop'"
    done
    while :; do
        ask NAME "$NAME" "VM name"
        [[ -n $NAME ]] && break
        echo "  required"
    done
    ask USERNAME "$USERNAME" "Username"
    ask VCPUS    "$VCPUS"    "vCPUs"
    ask MEM_MB   "$MEM_MB"   "Memory (MiB)"
    ask DISK_GB  "$DISK_GB"  "Disk (GiB)"
    if [[ $VARIANT == desktop ]]; then
        ask_yn RDP "$RDP" "Enable Remote Login (RDP on :3389, same creds as user)?"
    fi
fi

if (( RDP )) && [[ $VARIANT != desktop ]]; then
    echo "--rdp only applies to --desktop; ignoring" >&2
    RDP=0
fi

[[ -n $NAME ]] || { echo "VM_NAME required (or use -i)" >&2; exit 2; }
[[ $NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$ ]] || { echo "VM_NAME must match ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}\$ (got: $NAME)" >&2; exit 2; }
[[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}\$?$ ]] || { echo "USERNAME must be a valid POSIX user name (got: $USERNAME)" >&2; exit 2; }

case $VARIANT in
    server)  ISO_NAME=ubuntu-26.04-live-server-amd64.iso;;
    desktop) ISO_NAME=ubuntu-26.04-desktop-amd64.iso;;
esac
ISO=$IMG_DIR/$ISO_NAME

if [[ ! -r $ISO ]]; then
    DL=1
    (( INTERACTIVE )) && ask_yn DL 1 "ISO not found at $ISO. Download from releases.ubuntu.com (~5 GB)?"
    (( DL )) || { echo "ISO not readable: $ISO" >&2; exit 1; }
    command -v curl >/dev/null || { echo "curl required to fetch ISO" >&2; exit 1; }
    URL=https://releases.ubuntu.com/26.04/$ISO_NAME
    echo "Downloading $ISO_NAME (sudo needed to write to $IMG_DIR)..."
    sudo install -d -m 0711 "$IMG_DIR"
    sudo curl -fL --retry 3 -o "$ISO" "$URL"
    sudo chmod 0644 "$ISO"
    if SUMS=$(curl -fsSL "https://releases.ubuntu.com/26.04/SHA256SUMS"); then
        EXPECTED=$(printf '%s\n' "$SUMS" | grep -F "$ISO_NAME" | awk '{print $1; exit}')
        if [[ -n $EXPECTED ]]; then
            ACTUAL=$(sha256sum "$ISO" | awk '{print $1}')
            [[ $ACTUAL == "$EXPECTED" ]] || { echo "checksum mismatch for $ISO" >&2; sudo rm -f "$ISO"; exit 1; }
            echo "checksum verified"
        else
            echo "warning: $ISO_NAME not in SHA256SUMS — skipping verify" >&2
        fi
    else
        echo "warning: could not fetch SHA256SUMS — skipping verify" >&2
    fi
fi

[[ -r $ISO ]] || { echo "ISO not readable: $ISO" >&2; exit 1; }

declare -A PKG_FOR=([mkpasswd]=whois [cloud-localds]=cloud-image-utils [virt-install]=virtinst [genisoimage]=genisoimage)
missing=()
for t in mkpasswd cloud-localds virt-install genisoimage; do
    command -v "$t" >/dev/null || missing+=("$t")
done
if (( ${#missing[@]} )); then
    pkgs=()
    for t in "${missing[@]}"; do pkgs+=("${PKG_FOR[$t]}"); done
    echo "installing missing tools (${missing[*]}) via sudo apt: ${pkgs[*]}"
    sudo apt-get install -y "${pkgs[@]}"
fi

if [[ -n ${MAKEVM_PASSWORD:-} ]]; then
    PW=$MAKEVM_PASSWORD
else
    read -rsp "Password for $USERNAME on $NAME: " PW; echo
    read -rsp "Confirm: " PW2; echo
    [[ $PW == "$PW2" ]] || { echo "passwords do not match" >&2; exit 1; }
    unset PW2
fi
HASH=$(printf '%s' "$PW" | mkpasswd -m sha-512 -s)

if (( RDP )); then
    case $PW in
        *\'*) echo "RDP setup can't handle ' in passwords; choose another or skip --rdp" >&2; exit 1;;
    esac
fi

WORK=$(mktemp -d)
cleanup() {
    local rc=$?
    rm -rf "$WORK"
    if (( rc != 0 )) && [[ -n ${SEED:-} && -f $SEED ]]; then
        rm -f "$SEED"
    fi
}
trap cleanup EXIT

cat > "$WORK/meta-data" <<EOF
instance-id: iid-$NAME
local-hostname: $NAME
EOF

{
cat <<EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    hostname: $NAME
    realname: $USERNAME
    username: $USERNAME
    password: "$HASH"
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - qemu-guest-agent
    - openssh-server
EOF
(( RDP )) && echo "    - gnome-remote-desktop"
(( KEEP_CDROM )) || echo "  shutdown: poweroff"
cat <<EOF
  late-commands:
EOF
if (( PASSWORDLESS_SUDO )); then
cat <<EOF
    - "echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/90-$USERNAME"
    - "chmod 440 /target/etc/sudoers.d/90-$USERNAME"
EOF
fi
if (( RDP )); then
cat <<EOF
    - "curtin in-target --target=/target -- install -d -m 750 -o gnome-remote-desktop -g gnome-remote-desktop /etc/gnome-remote-desktop"
    - "curtin in-target --target=/target -- openssl req -x509 -newkey rsa:4096 -nodes -keyout /etc/gnome-remote-desktop/rdp-tls.key -out /etc/gnome-remote-desktop/rdp-tls.crt -subj '/CN=$NAME' -days 3650"
    - "curtin in-target --target=/target -- chown gnome-remote-desktop:gnome-remote-desktop /etc/gnome-remote-desktop/rdp-tls.crt /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- chmod 640 /etc/gnome-remote-desktop/rdp-tls.crt /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- grdctl --system rdp set-tls-cert /etc/gnome-remote-desktop/rdp-tls.crt"
    - "curtin in-target --target=/target -- grdctl --system rdp set-tls-key /etc/gnome-remote-desktop/rdp-tls.key"
    - "curtin in-target --target=/target -- grdctl --system rdp set-credentials '$USERNAME' '$PW'"
    - "curtin in-target --target=/target -- grdctl --system rdp enable"
    - "curtin in-target --target=/target -- systemctl enable gnome-remote-desktop.service"
    - "curtin in-target --target=/target -- bash -c 'rm -f /var/log/installer/autoinstall-user-data /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/user-data.txt.i; rm -rf /var/lib/cloud/seed /var/lib/cloud/seeds; for f in /var/log/installer/*.log /var/log/cloud-init.log /var/log/cloud-init-output.log; do [ -f \"\$f\" ] && : > \"\$f\"; done; journalctl --rotate; journalctl --vacuum-time=1s'"
EOF
fi
} > "$WORK/user-data"
unset PW

SEED_DIR=$IMG_DIR/seeds
if [[ ! -w $SEED_DIR ]]; then
    sudo install -d -o "$USER" -m 0755 "$SEED_DIR"
fi
SEED=$SEED_DIR/seed-$NAME.iso
cloud-localds "$SEED" "$WORK/user-data" "$WORK/meta-data"

if [[ $VARIANT == desktop ]]; then
    GRAPHICS=(--graphics spice --graphics vnc,listen=127.0.0.1 --video qxl)
else
    GRAPHICS=(--graphics vnc,listen=127.0.0.1 --video cirrus)
fi

virt-install \
    --connect qemu:///system \
    --name "$NAME" \
    --memory "$MEM_MB" \
    --vcpus "$VCPUS" \
    --disk "size=$DISK_GB,format=qcow2" \
    --disk "path=$SEED,device=cdrom" \
    --location "$ISO,kernel=casper/vmlinuz,initrd=casper/initrd" \
    --extra-args "autoinstall ds=nocloud" \
    --osinfo "detect=on,name=ubuntu24.04" \
    --network network=default \
    --noautoconsole \
    "${GRAPHICS[@]}"

if (( ! KEEP_CDROM )); then
    LOG_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/make-vm
    mkdir -p "$LOG_DIR"
    LOG=$LOG_DIR/${NAME}-cleanup.log
    setsid -f bash -c '
        name=$1 seed=$2 log=$3
        exec >>"$log" 2>&1
        echo "[$(date -Is)] watcher started; waiting for $name to power off"
        deadline=$(( $(date +%s) + 7200 ))
        while (( $(date +%s) < deadline )); do
            state=$(virsh -c qemu:///system domstate "$name" 2>/dev/null) || { echo "[$(date -Is)] domain gone"; exit 1; }
            if [[ $state == "shut off" ]]; then
                echo "[$(date -Is)] $name shut off; detaching cdroms"
                while read -r dev; do
                    [[ -z $dev ]] && continue
                    echo "[$(date -Is)] detach $dev"
                    virsh -c qemu:///system detach-disk "$name" "$dev" --config || true
                done < <(virsh -c qemu:///system domblklist "$name" --details | awk "\$2==\"cdrom\"{print \$3}")
                if [[ -f $seed ]]; then
                    rm -f "$seed" && echo "[$(date -Is)] removed seed $seed"
                fi
                echo "[$(date -Is)] starting $name"
                virsh -c qemu:///system start "$name" && echo "[$(date -Is)] done"
                exit 0
            fi
            sleep 10
        done
        echo "[$(date -Is)] timed out (2h) waiting for shut off"
        exit 1
    ' _ "$NAME" "$SEED" "$LOG" </dev/null >/dev/null 2>&1
fi

cat <<EOF

VM "$NAME" is installing. Watch progress in Cockpit (Virtual Machines tab) or:
  virsh -c qemu:///system console $NAME    # serial console (server)
  virt-viewer --connect qemu:///system $NAME   # graphical (desktop)

After install completes the VM $( (( KEEP_CDROM )) && echo "reboots" || echo "powers off, then a background watcher detaches the CDROMs, deletes the seed ISO, and restarts it" ); log in as: $USERNAME
EOF
(( KEEP_CDROM )) || echo "Watcher log: $LOG"

if (( RDP )); then
cat <<EOF
RDP enabled: connect to <vm-ip>:3389 with username "$USERNAME" and the same password.
  ip:   virsh -c qemu:///system domifaddr $NAME
Guest scrub on install: cloud-init/installer logs truncated, cached user-data deleted,
journal vacuumed.$( (( KEEP_CDROM )) && printf '\nHost seed ISO still contains plaintext — delete it after first boot:\n  rm /var/lib/libvirt/images/seeds/seed-%s.iso' "$NAME" )
EOF
fi

#!/bin/bash
set -euo pipefail

# Wipes a selected whole disk, builds LVM PV -> VG -> LV -> XFS, mounts it,
# and defines a libvirt directory storage pool on top.

VG_NAME="vmstore"
LV_NAME="vms"
FS_LABEL="vmstore"
MOUNT_POINT="/mnt/vmstore"
POOL_NAME="vmstore"
FSTAB_OPTS="defaults,nofail,x-systemd.device-timeout=10s"

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

disks_of_mount() {
    local mp="$1" src
    src=$(findmnt -no SOURCE "$mp" 2>/dev/null || true)
    [ -z "$src" ] && return 0
    lsblk -nso NAME,TYPE "$src" 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}'
}

declare -A FORBIDDEN
for mp in / /boot /boot/efi; do
    while read -r d; do
        [ -n "$d" ] && FORBIDDEN[$d]=1
    done < <(disks_of_mount "$mp")
done

while read -r swap_src; do
    [ -z "$swap_src" ] && continue
    while read -r d; do
        [ -n "$d" ] && FORBIDDEN[$d]=1
    done < <(lsblk -nso NAME,TYPE "$swap_src" 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}')
done < <(swapon --show=NAME --noheadings 2>/dev/null || true)

mapfile -t all_disks < <(lsblk -dnpo NAME,TYPE | awk '$2=="disk"{print $1}')

candidates=()
for d in "${all_disks[@]}"; do
    case "$(basename "$d")" in
        mmcblk*|loop*|zram*|sr*|fd*) continue ;;
    esac
    [ -n "${FORBIDDEN[$d]:-}" ] && continue
    candidates+=("$d")
done

if [ ${#candidates[@]} -eq 0 ]; then
    echo "No eligible disks found (all detected disks host the OS or are excluded)."
    exit 1
fi

disk_summary() {
    local d="$1"
    local sz model serial tran parts vgs_on
    sz=$(lsblk -ndo SIZE "$d")
    model=$(lsblk -ndo MODEL "$d" | sed 's/[[:space:]]*$//')
    [ -z "$model" ] && model="(no model)"
    serial=$(lsblk -ndo SERIAL "$d" 2>/dev/null | sed 's/[[:space:]]*$//')
    [ -z "$serial" ] && serial="(no serial)"
    tran=$(lsblk -ndo TRAN "$d" 2>/dev/null | sed 's/[[:space:]]*$//')
    [ -z "$tran" ] && tran="?"
    parts=$(lsblk -nrpo NAME,TYPE "$d" | awk '$2=="part"' | wc -l)
    if command -v pvs >/dev/null 2>&1; then
        vgs_on=$(pvs --noheadings -o pv_name,vg_name 2>/dev/null \
            | awk -v dd="$d" '($1==dd || $1 ~ "^"dd"[0-9]") && $2!=""{print $2}' \
            | sort -u | tr '\n' ',' | sed 's/,$//')
        [ -z "$vgs_on" ] && vgs_on="(no LVM)"
    else
        vgs_on="(lvm2 not installed yet)"
    fi
    printf "%-14s %-8s %-6s %-30s ser=%-22s parts=%-2d VGs=%s\n" \
        "$d" "$sz" "$tran" "$model" "$serial" "$parts" "$vgs_on"
}

echo
echo "Eligible disks (disks hosting /, /boot, /boot/efi excluded):"
i=1
for d in "${candidates[@]}"; do
    printf "  %d) " "$i"
    disk_summary "$d"
    i=$((i+1))
done
echo

read -r -p "Select the number of the disk to use for the '$POOL_NAME' VM storage pool: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#candidates[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

DISK="${candidates[$((choice-1))]}"

mapfile -t mounted < <(lsblk -nrpo MOUNTPOINT "$DISK" | grep -v '^$' || true)
if [ ${#mounted[@]} -gt 0 ]; then
    echo "Refusing to wipe $DISK: the following are currently mounted on it or its descendants:"
    printf "  %s\n" "${mounted[@]}"
    exit 1
fi

echo
echo "Selected: $DISK"
echo "Current state of $DISK:"
lsblk "$DISK" || true

if command -v pvs >/dev/null 2>&1; then
    vgs_to_remove=$(pvs --noheadings -o pv_name,vg_name 2>/dev/null \
        | awk -v dd="$DISK" '($1==dd || $1 ~ "^"dd"[0-9]") && $2!=""{print $2}' | sort -u)
else
    vgs_to_remove=""
fi
if [ -n "$vgs_to_remove" ]; then
    echo
    echo "LVM volume groups that will be REMOVED:"
    printf "  %s\n" $vgs_to_remove
fi

echo
echo "Target layout:"
echo "  $DISK -> GPT -> partition 1 -> LVM PV -> VG '$VG_NAME' -> LV '$LV_NAME' -> XFS"
echo "  Mounted at $MOUNT_POINT via /etc/fstab (UUID)"
echo "  libvirt directory pool '$POOL_NAME' targeting $MOUNT_POINT (autostart)"
echo

sel_summary=$(disk_summary "$DISK")
echo
echo "Final confirmation. Selected disk:"
echo "  $sel_summary"
echo
read -r -p "Type 'WIPE $DISK' exactly to proceed: " confirm
if [ "$confirm" != "WIPE $DISK" ]; then
    echo "Aborted."
    exit 1
fi

need_pkgs=()
command -v parted   >/dev/null 2>&1 || need_pkgs+=("parted")
command -v pvcreate >/dev/null 2>&1 || need_pkgs+=("lvm2")
command -v mkfs.xfs >/dev/null 2>&1 || need_pkgs+=("xfsprogs")
command -v virsh    >/dev/null 2>&1 || need_pkgs+=("libvirt-clients")

if [ ${#need_pkgs[@]} -gt 0 ]; then
    echo "Installing required packages: ${need_pkgs[*]}"
    apt-get update -y
    apt-get install -y "${need_pkgs[@]}"
fi

echo "==> Tearing down existing LVM on $DISK (if any)..."
for vg in $vgs_to_remove; do
    echo "  vgchange -an $vg"
    vgchange -an "$vg" || true
    echo "  vgremove -f -y $vg"
    vgremove -f -y "$vg" || true
done

mapfile -t pvs_to_remove < <(pvs --noheadings -o pv_name 2>/dev/null \
    | awk -v dd="$DISK" '$1==dd || $1 ~ "^"dd"[0-9]" {print $1}')
for pv in "${pvs_to_remove[@]:-}"; do
    [ -z "$pv" ] && continue
    echo "  pvremove -ff -y $pv"
    pvremove -ff -y "$pv" || true
done

echo "==> Wiping signatures from $DISK and any partitions..."
mapfile -t parts < <(lsblk -nrpo NAME,TYPE "$DISK" | awk '$2=="part"{print $1}')
for p in "${parts[@]:-}"; do
    [ -z "$p" ] && continue
    wipefs -af "$p" || true
done
wipefs -af "$DISK"
partprobe "$DISK" 2>/dev/null || true
udevadm settle || true

echo "==> Creating GPT + partition on $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary 0% 100%
parted -s "$DISK" set 1 lvm on
partprobe "$DISK" 2>/dev/null || true
udevadm settle || true

PART=""
for _ in 1 2 3 4 5; do
    if   [ -b "${DISK}1" ];  then PART="${DISK}1"; break
    elif [ -b "${DISK}p1" ]; then PART="${DISK}p1"; break
    fi
    sleep 1
    udevadm settle || true
done
if [ -z "$PART" ]; then
    PART=$(lsblk -nrpo NAME,TYPE "$DISK" | awk '$2=="part"{print $1; exit}')
fi
[ -z "$PART" ] && { echo "Could not find new partition on $DISK." >&2; exit 1; }
echo "  Partition: $PART"

echo "==> Creating PV / VG / LV..."
pvcreate -ff -y "$PART"
vgcreate "$VG_NAME" "$PART"
lvcreate -l 100%FREE -n "$LV_NAME" "$VG_NAME"

LV_DEV="/dev/$VG_NAME/$LV_NAME"

echo "==> Formatting $LV_DEV as XFS (label=$FS_LABEL)..."
mkfs.xfs -f -L "$FS_LABEL" "$LV_DEV"

mkdir -p "$MOUNT_POINT"

UUID=$(blkid -s UUID -o value "$LV_DEV")
[ -z "$UUID" ] && { echo "Could not read UUID of $LV_DEV." >&2; exit 1; }

if grep -q "UUID=$UUID" /etc/fstab; then
    echo "==> /etc/fstab already has an entry for UUID=$UUID, leaving it as-is."
else
    echo "==> Adding fstab entry for UUID=$UUID"
    printf "UUID=%s  %s  xfs  %s  0  2\n" "$UUID" "$MOUNT_POINT" "$FSTAB_OPTS" >> /etc/fstab
fi

systemctl daemon-reload || true

if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT" || true
fi
mount "$MOUNT_POINT"

echo "==> Configuring libvirt directory pool '$POOL_NAME'..."
if virsh pool-info "$POOL_NAME" >/dev/null 2>&1; then
    echo "  Pool '$POOL_NAME' already exists; skipping define/build."
else
    virsh pool-define-as "$POOL_NAME" dir --target "$MOUNT_POINT"
    virsh pool-build "$POOL_NAME"
fi

pool_state=$(virsh pool-info "$POOL_NAME" 2>/dev/null | awk -F': *' '/^State/{print $2}')
if [ "$pool_state" != "running" ]; then
    virsh pool-start "$POOL_NAME"
fi
virsh pool-autostart "$POOL_NAME" >/dev/null

echo
echo "================ DONE ================"
lsblk "$DISK"
echo
df -hT "$MOUNT_POINT"
echo
virsh pool-info "$POOL_NAME"
echo
echo "Open Cockpit -> Virtual Machines -> Storage pools to see '$POOL_NAME'."

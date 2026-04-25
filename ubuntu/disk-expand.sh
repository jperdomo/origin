#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as 'root' or with 'sudo' to function."
    exit 1
fi

if ! command -v growpart >/dev/null 2>&1; then
    echo "Installing cloud-guest-utils (provides growpart)..."
    apt-get update -y
    apt-get install -y cloud-guest-utils
fi

echo
echo "Current block devices:"
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
echo

mapfile -t candidates < <(lsblk -nrpo NAME,FSTYPE,TYPE,MOUNTPOINT \
    | awk '$2 ~ /^(ext2|ext3|ext4|xfs)$/ && ($3=="lvm" || $3=="part") && $4 != "" {print $1"|"$2"|"$3"|"$4}')

if [ ${#candidates[@]} -eq 0 ]; then
    echo "No expandable mounted ext*/xfs filesystems found."
    exit 1
fi

echo "Expandable filesystems:"
i=1
for c in "${candidates[@]}"; do
    IFS='|' read -r dev fs type mnt <<< "$c"
    size=$(lsblk -nrdo SIZE "$dev")
    printf "  %d) %-40s %-6s %-4s %-8s mount=%s\n" "$i" "$dev" "$fs" "$type" "$size" "$mnt"
    i=$((i+1))
done

echo
read -r -p "Select the number of the filesystem to expand to 100%: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#candidates[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

IFS='|' read -r dev fs type mnt <<< "${candidates[$((choice-1))]}"

echo
echo "About to expand $dev ($fs on $type) mounted at $mnt to fill all available space."
read -r -p "Type YES to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

resolve_parent() {
    local child="$1"
    local parent
    parent=$(lsblk -nrpo PKNAME "$child" | head -n1)
    [ -z "$parent" ] && return 1
    [[ "$parent" != /dev/* ]] && parent="/dev/$parent"
    echo "$parent"
}

partnum_of() {
    echo "$1" | grep -oE '[0-9]+$'
}

grow_partition() {
    local part="$1"
    local parent
    if ! parent=$(resolve_parent "$part"); then
        echo "  Could not resolve parent disk for $part; skipping growpart."
        return 0
    fi
    local num
    num=$(partnum_of "$part")
    echo "Growing partition $part (disk $parent, part $num)..."
    set +e
    growpart "$parent" "$num"
    local rc=$?
    set -e
    if [ $rc -eq 0 ]; then
        echo "  Partition grown."
    elif [ $rc -eq 1 ]; then
        echo "  growpart reported nothing to do (already at max)."
    else
        echo "  growpart exited with code $rc."
    fi
}

if [ "$type" = "lvm" ]; then
    vg=$(lvs --noheadings -o vg_name "$dev" | tr -d ' ')
    echo "Volume group: $vg"

    while read -r pv; do
        pv=$(echo "$pv" | tr -d ' ')
        [ -z "$pv" ] && continue
        ptype=$(lsblk -nrdo TYPE "$pv")
        if [ "$ptype" = "part" ]; then
            grow_partition "$pv"
        fi
        echo "Resizing PV $pv..."
        pvresize "$pv"
    done < <(pvs --noheadings -o pv_name -S vg_name="$vg")

    echo "Extending LV $dev to use all free space in $vg..."
    set +e
    lvextend -l +100%FREE "$dev"
    set -e
else
    grow_partition "$dev"
fi

echo "Resizing filesystem on $dev..."
case "$fs" in
    ext2|ext3|ext4)
        resize2fs "$dev"
        ;;
    xfs)
        xfs_growfs "$mnt"
        ;;
    *)
        echo "Unsupported filesystem: $fs"
        exit 1
        ;;
esac

echo
echo "Done. New size:"
df -hT "$mnt"

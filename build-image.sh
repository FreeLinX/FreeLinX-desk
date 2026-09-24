#!/bin/sh
# FreeLinX Desktop - Package the initramfs image from src/rootfs
# Git cannot store modes or a matching kernel, so we pack from a staging copy:
#   - kernel/bzImage is copied to /boot/vmlinuz (installer + image always match)
#   - /etc/shadow 0600, /root 0700, /tmp 1777, doas setuid
#   - optional: FLX_ROOT_HASH=<crypt hash> replaces the committed root hash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="${SCRIPT_DIR}/src/rootfs"
KERNEL="${FLX_KERNEL:-${SCRIPT_DIR}/kernel/bzImage}"
BUILD_DIR="${SCRIPT_DIR}/src/build"
OUT_DIR="${BUILD_DIR}/x86_64"
OUT_IMG="${OUT_DIR}/freelinx-desktop.img.gz"
STAGE="${BUILD_DIR}/stage"

for t in cpio gzip find tar; do
    command -v "$t" >/dev/null 2>&1 || { echo "Error: '$t' is required but not installed." >&2; exit 1; }
done
[ -d "$ROOTFS" ] || { echo "Error: rootfs not found: $ROOTFS" >&2; exit 1; }
[ -f "$KERNEL" ] || { echo "Error: kernel not found: $KERNEL" >&2; exit 1; }

echo "Staging rootfs from: $ROOTFS"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT_DIR"
trap 'rm -rf "$STAGE"' EXIT INT TERM
(cd "$ROOTFS" && tar -cf - .) | (cd "$STAGE" && tar -xf -)

mkdir -p "$STAGE/boot"
cp -f "$KERNEL" "$STAGE/boot/vmlinuz"

if [ -n "${FLX_ROOT_HASH:-}" ]; then
    _day=$(( $(date +%s) / 86400 ))
    sed "s|^root:[^:]*:[^:]*:|root:${FLX_ROOT_HASH}:${_day}:|" "$STAGE/etc/shadow" > "$STAGE/etc/shadow.new"
    mv -f "$STAGE/etc/shadow.new" "$STAGE/etc/shadow"
fi

chmod 0600 "$STAGE/etc/shadow"
chmod 0700 "$STAGE/root"
chmod 1777 "$STAGE/tmp"
[ -d "$STAGE/var/tmp" ] && chmod 1777 "$STAGE/var/tmp"
[ -f "$STAGE/usr/bin/doas" ] && chmod 4755 "$STAGE/usr/bin/doas"
[ -f "$STAGE/etc/doas.conf" ] && chmod 0600 "$STAGE/etc/doas.conf"

find "$STAGE" -name .gitkeep -type f -exec rm -f {} +

echo "Packing FreeLinX Desktop initramfs ..."
(cd "$STAGE" && find . -print0 | cpio --null -o --quiet --format=newc --owner=0:0 | gzip -1 > "$OUT_IMG")
ln -sf "src/build/x86_64/freelinx-desktop.img.gz" "${SCRIPT_DIR}/initrd.img"
echo "Build complete: $OUT_IMG ($(du -h "$OUT_IMG" | cut -f1))"

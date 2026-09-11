#!/bin/sh
# FreeLinX Desktop - Package initramfs image from src/rootfs
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="${SCRIPT_DIR}/src/rootfs"
OUT_DIR="${SCRIPT_DIR}/src/build/x86_64"
OUT_IMG="${OUT_DIR}/freelinx-desktop.img.gz"

echo "Packing FreeLinX Desktop initramfs from: $ROOTFS"
mkdir -p "$OUT_DIR"
(cd "$ROOTFS" && find . -print0 | cpio --null -ov --format=newc | gzip -1 > "$OUT_IMG")
cp -p "$OUT_IMG" "${SCRIPT_DIR}/src/build/freelinx-desktop.img.gz" 2>/dev/null || true

echo "Build complete: $OUT_IMG ($(du -h "$OUT_IMG" | cut -f1))"

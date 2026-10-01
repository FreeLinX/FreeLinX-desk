#!/bin/sh
# FreeLinX Desktop - Package the initramfs image from src/rootfs
# Git cannot store modes or a matching kernel, so we pack from a staging copy:
#   - kernel/bzImage is copied to /boot/vmlinuz (installer + image always match)
#   - /etc/shadow 0600, /root 0700, /tmp 1777, doas + Xorg setuid
#   - optional: FLX_ROOT_HASH=<crypt hash> replaces the committed root hash
#   - optional: FLX_FIRMWARE_TARBALL=<path> stages /lib/firmware
#
# FIRMWARE
# src/.gitignore deliberately keeps rootfs/lib/firmware/ out of version
# control: the blobs are ~94 MB of vendor code.  But an image built without
# them boots to a desktop that has no WiFi, no webcam bridge and no audio
# codec firmware on real hardware, which looks exactly like a broken kernel.
# So firmware is staged here from a release tarball, and a release build
# (FLX_REQUIRE_FIRMWARE=1) refuses to produce an image without it.
# Build the tarball with ./make-firmware-tarball.sh.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="${SCRIPT_DIR}/src/rootfs"
KERNEL="${FLX_KERNEL:-${SCRIPT_DIR}/kernel/bzImage}"
BUILD_DIR="${SCRIPT_DIR}/src/build"
OUT_DIR="${BUILD_DIR}/x86_64"
OUT_IMG="${OUT_DIR}/freelinx-desktop.img.gz"
STAGE="${BUILD_DIR}/stage"

# Release firmware tarball. The kernel release it must match is read from
# kernel/ if available, otherwise any firmware-*.tar.xz next to this script
# is accepted (the blobs are per-kernel-version but compatible within 6.6.x).
FW_TARBALL="${FLX_FIRMWARE_TARBALL:-}"
if [ -z "$FW_TARBALL" ]; then
    for cand in "$SCRIPT_DIR"/firmware-*.tar.xz; do
        [ -f "$cand" ] && FW_TARBALL="$cand" && break
    done
fi

for t in cpio zstd find tar; do
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

# --- firmware -------------------------------------------------------------
# Staged from the release tarball into the image, never committed to the
# rootfs tree.  Without it the desktop boots but every device needing a
# firmware blob (Intel/Realtek/Atheros WiFi, Broadcom, audio codec) silently
# fails to initialise on real hardware.
if [ -n "$FW_TARBALL" ] && [ -f "$FW_TARBALL" ]; then
    echo "Staging firmware from: $FW_TARBALL"
    # The tarball is laid out as lib/firmware/... so it unpacks straight into
    # the stage.  Do NOT add --strip-components here: that would drop the blobs
    # at <stage>/ath10k/... instead of <stage>/lib/firmware/ath10k/..., and the
    # image would look staged while every driver failed to find its blob.
    tar -xf "$FW_TARBALL" -C "$STAGE" lib/firmware
    FW_COUNT=$(find "$STAGE/lib/firmware" -type f 2>/dev/null | wc -l)
    echo "Firmware staged: $FW_COUNT files ($(du -sh "$STAGE/lib/firmware" 2>/dev/null | cut -f1))"
    if [ "$FW_COUNT" -eq 0 ]; then
        echo "Error: firmware tarball unpacked to 0 files: $FW_TARBALL" >&2
        exit 1
    fi
    # Guard the layout itself, not just the count.
    if [ ! -d "$STAGE/lib/firmware/ath10k" ] && [ ! -d "$STAGE/lib/firmware/rtw88" ] \
       && [ ! -f "$STAGE/lib/firmware/iwlwifi-7260-17.ucode" ]; then
        echo "Error: firmware unpacked to the wrong layout (no known vendor" >&2
        echo "       subdirectory directly under $STAGE/lib/firmware)." >&2
        exit 1
    fi
else
    MSG="firmware tarball not found (looked for $SCRIPT_DIR/firmware-*.tar.xz)."
    if [ "${FLX_REQUIRE_FIRMWARE:-0}" = "1" ]; then
        echo "Error: $MSG" >&2
        echo "       Run ./make-firmware-tarball.sh, or set FLX_FIRMWARE_TARBALL." >&2
        exit 1
    fi
    echo "Warning: $MSG" >&2
    echo "         The image will have no /lib/firmware; WiFi, webcam bridges and" >&2
    echo "         audio codecs will not initialise on real hardware." >&2
fi

# --- package database ------------------------------------------------------
# Register the desktop stack in the image's xpkg database, so `xpkg list`,
# `xpkg upgrade` and `xpkg verify` see what the system really runs.  The
# packages (stack/package-stack.sh) are the same builds install-stack.sh
# copied; installing them over the staged tree records every file they own.
PKGS_DIR="${FLX_PACKAGES:-$SCRIPT_DIR/stack/work/pkgs}"
XPKG_HOST="$SCRIPT_DIR/stack/work/sysroot/usr/bin/xpkg"
MUSL_RUN="$SCRIPT_DIR/stack/work/bin/musl-run"
if [ "${FLX_REGISTER_PACKAGES:-1}" = 1 ] && [ -x "$XPKG_HOST" ] && ls "$PKGS_DIR"/*.xpkg >/dev/null 2>&1; then
    echo "Registering $(ls "$PKGS_DIR"/*.xpkg | wc -l) packages in the image database"
    XPKG_ROOT="$STAGE" NO_COLOR=1 "$MUSL_RUN" "$XPKG_HOST" --quiet --no-scripts install "$PKGS_DIR"/*.xpkg \
        > "${BUILD_DIR}/xpkg-register.log" 2>&1 || {
        tail -20 "${BUILD_DIR}/xpkg-register.log" >&2
        echo "Error: registering packages failed" >&2
        exit 1
    }
    # the image's own configuration wins over the packaged defaults
    find "$STAGE/etc" -name '*.xpkgnew' -type f -delete
    rm -rf "$STAGE/var/cache/xpkg" "$STAGE/var/lib/xpkg/lock"
    echo "Package database: $("$MUSL_RUN" "$XPKG_HOST" --root "$STAGE" list 2>/dev/null | wc -l) packages"
fi

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
[ -f "$STAGE/usr/sbin/unix_chkpwd" ] && chmod 4755 "$STAGE/usr/sbin/unix_chkpwd"
# su and newgrp switch identity, so they run setuid root as on NetBSD
for b in bin/su bin/newgrp; do [ -f "$STAGE/$b" ] && chmod 4755 "$STAGE/$b"; done
# Xorg is setuid root (the classic Xorg.wrap model): a user session started by
# greetd has no seat manager to hand it the console and framebuffer.
[ -f "$STAGE/usr/bin/Xorg" ] && chmod 4711 "$STAGE/usr/bin/Xorg"
[ -f "$STAGE/usr/sbin/unix_chkpwd" ] || [ ! -f "$STAGE/sbin/unix_chkpwd" ] || chmod 4755 "$STAGE/sbin/unix_chkpwd"
# linux-pam's pam_unix forks the helper at /sbin/unix_chkpwd (CHKPWD_HELPER);
# /usr/sbin is where we install the binary -> provide the expected path.
if [ -f "$STAGE/usr/sbin/unix_chkpwd" ] && [ ! -e "$STAGE/sbin/unix_chkpwd" ]; then
    ln -s ../usr/sbin/unix_chkpwd "$STAGE/sbin/unix_chkpwd"
fi
[ -f "$STAGE/etc/doas.conf" ] && chmod 0600 "$STAGE/etc/doas.conf"

find "$STAGE" -name .gitkeep -type f -exec rm -f {} +

# Release gate: nothing GCC-built or glibc-linked may ship.
# FLX_ALLOW_GNU=1 skips it for local experiments only.
if [ "${FLX_ALLOW_GNU:-0}" != "1" ]; then
    if ! "${SCRIPT_DIR}/check-nognu.sh" "$STAGE" > "${BUILD_DIR}/check-nognu.txt" 2>&1; then
        grep '^FAIL' "${BUILD_DIR}/check-nognu.txt" >&2
        echo "Error: GNU/glibc artefacts in the image (see ${BUILD_DIR}/check-nognu.txt)." >&2
        exit 1
    fi
    tail -1 "${BUILD_DIR}/check-nognu.txt"
fi

echo "Packing FreeLinX Desktop initramfs ..."
(cd "$STAGE" && find . -print0 | cpio --null -o --quiet --format=newc --owner=0:0 | zstd -q -T0 -12 > "$OUT_IMG")
ln -sf "src/build/x86_64/freelinx-desktop.img.gz" "${SCRIPT_DIR}/initrd.img"
echo "Build complete: $OUT_IMG ($(du -h "$OUT_IMG" | cut -f1))"

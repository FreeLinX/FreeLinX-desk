#!/bin/sh
# FreeLinX Desktop - build the release firmware tarball.
#
# src/.gitignore keeps rootfs/lib/firmware/ out of version control: the blobs
# are ~94 MB of vendor code that change on a completely different schedule
# from FreeLinX.  They still have to reach the machine, though - a desktop
# without /lib/firmware has no Intel/Realtek/Atheros WiFi, no Broadcom blobs
# and no audio codec firmware, which on real hardware looks exactly like a
# broken kernel.
#
# This script collects a firmware tree into firmware-<kver>.tar.xz, laid out
# so that build-image.sh can unpack it with:
#     tar -xf firmware-<kver>.tar.xz -C <stage> --strip-components=2 lib/firmware
#
# Usage:
#   ./make-firmware-tarball.sh                       # from a staged source tree
#   ./make-firmware-tarball.sh /path/to/firmware     # explicit source tree
#
# The source tree may be given several times and may come from the host's
# /lib/firmware (Debian's firmware-linux-free/non-free packages), from the
# base src/rootfs, or from linux-firmware unpacked anywhere.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${FLX_FIRMWARE_OUT_DIR:-$SCRIPT_DIR}"

# Kernel release the tarball is named for.  The tarball name has to match the
# kernel the image will boot: the blobs live in /lib/firmware/<modalias> but
# the rootfs also stages /lib/modules/<kver>, and a mismatch means the driver
# is never loaded.  Sources, in order:
#   1. FLX_KERNEL_VERSION
#   2. a kernel source checkout in the workspace (../kernel/linux-*/Makefile)
#   3. the version string compiled into the Desktop-test kernel/bzImage
# Never fall back to `uname -r`: that is the *host* kernel and would produce a
# release artifact named after the wrong release (e.g. firmware-6.1.0-50-amd64).
KVER="${FLX_KERNEL_VERSION:-}"
if [ -z "$KVER" ]; then
    for mk in "$SCRIPT_DIR"/../kernel/linux-*/Makefile \
              "$SCRIPT_DIR"/../kernel/Makefile; do
        [ -f "$mk" ] || continue
        KVER=$(awk '/^VERSION = /{v=$3} /^PATCHLEVEL = /{p=$3} /^SUBLEVEL = /{s=$3}
                     END{ if (v!=""&&p!="") print v"."p"."(s==""?0:s) }' "$mk")
        [ -n "$KVER" ] && break
    done
fi
if [ -z "$KVER" ] && [ -f "$SCRIPT_DIR/kernel/bzImage" ]; then
    # bzImage carries "<kver> (<builder>) #<n> ..." from the build banner.
    KVER=$(strings "$SCRIPT_DIR/kernel/bzImage" 2>/dev/null \
           | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\) (.*) #.*/\1/p' \
           | head -1)
fi
if [ -z "$KVER" ]; then
    echo "error: cannot determine the FreeLinX kernel release." >&2
    echo "       Set FLX_KERNEL_VERSION=<kver> (e.g. 6.6.21)." >&2
    exit 1
fi
OUT="$OUT_DIR/firmware-$KVER.tar.xz"

# Source trees: explicit args, else the base rootfs, else the host.
SRC=""
if [ "$#" -gt 0 ]; then
    SRC="$*"
elif [ -d "$SCRIPT_DIR/../src/rootfs/lib/firmware" ]; then
    SRC="$SCRIPT_DIR/../src/rootfs/lib/firmware"
elif [ -d /lib/firmware ]; then
    SRC=/lib/firmware
fi

[ -n "$SRC" ] || { echo "error: no firmware source tree found" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/lib/firmware"

echo "==> kernel release : $KVER"
echo "==> output         : $OUT"
for s in $SRC; do
    [ -d "$s" ] || { echo "error: not a directory: $s" >&2; exit 1; }
    echo "==> source         : $s ($(find "$s" -type f | wc -l) files)"
    cp -a "$s"/. "$WORK/lib/firmware/"
done

# De-duplicate by path, last one wins (already handled by cp -a overwrite),
# then report the final inventory so the log shows exactly what shipped.
COUNT=$(find "$WORK/lib/firmware" -type f | wc -l)
echo "==> staged         : $COUNT files, $(du -sh "$WORK/lib/firmware" | cut -f1)"
echo "==> families       :"
for d in "$WORK"/lib/firmware/*/; do
    [ -d "$d" ] || continue
    printf '    %-12s %5s files  %s\n' "$(basename "$d")" "$(find "$d" -type f | wc -l)" "$(du -sh "$d" | cut -f1)"
done

# Compress the tar stream: tar writes the archive, xz compresses it.
# (Reversing these two would feed compressed bytes into tar and silently
#  produce an unopenable archive.)
echo "==> compressing (this takes a minute)..."
rm -f "$OUT"
if ! tar -cf - -C "$WORK" lib | xz -9 -T0 -c > "$OUT"; then
    echo "error: compression pipeline failed" >&2
    rm -f "$OUT"
    exit 1
fi
[ -s "$OUT" ] || { echo "error: tarball is empty: $OUT" >&2; exit 1; }

# Prove the archive we just wrote actually round-trips, so a corrupt
# tarball can never be shipped as the release artifact.
if ! tar -tf "$OUT" >/dev/null 2>&1; then
    echo "error: produced tarball does not verify: $OUT" >&2
    exit 1
fi
tar -tf "$OUT" | grep -q '^lib/firmware/' || {
    echo "error: tarball lacks lib/firmware/ prefix: $OUT" >&2
    exit 1
}

echo "==> done: $OUT ($(du -h "$OUT" | cut -f1), $COUNT firmware files)"
cat <<EOF

Next:
  ./build-image.sh                    # stages it into the initramfs
  FLX_REQUIRE_FIRMWARE=1 ./build-image.sh   # refuse to build without it
EOF

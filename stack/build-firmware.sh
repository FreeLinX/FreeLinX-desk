#!/bin/sh
# FreeLinX Desktop - curated firmware tarball for the release image
#
# Picks the blobs the FreeLinX kernel's drivers ask for out of an upstream
# linux-firmware release and Sound Open Firmware (sof-bin), compresses each
# file with zstd (the kernel is built with FW_LOADER_COMPRESS_ZSTD, so it
# loads foo.bin.zst when asked for foo.bin - half the RAM in the live
# system), and writes firmware-<kver>.tar.xz for build-image.sh.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
W="${STACK_WORK:-$HERE/work}"
DIST="${STACK_DIST:-$TOP/ports/dist}"
LFW_VER="${LFW_VER:-20260916}"
LFW_SHA="f80dcb757a623deda62200c08e0e1a88c76fb6b54964f31b35fa74da1c90ccc5"
SOF_VER="${SOF_VER:-2026.09.1}"
KVER="${KVER:-6.6.21}"
OUT="$TOP/firmware-$KVER.tar.xz"

lfw="$DIST/linux-firmware-$LFW_VER.tar.xz"
[ -f "$lfw" ] || curl -fL -o "$lfw" "https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-$LFW_VER.tar.xz"
echo "$LFW_SHA  $lfw" | sha256sum -c -
sof="$DIST/sof-bin-$SOF_VER.tar.gz"
[ -f "$sof" ] || curl -fL -o "$sof" "https://github.com/thesofproject/sof-bin/releases/download/v$SOF_VER/sof-bin-$SOF_VER.tar.gz"

S="$W/fw-src"; T="$W/fw-stage"
rm -rf "$S" "$T"; mkdir -p "$S" "$T/lib/firmware"
tar -xJf "$lfw" -C "$S"
tar -xzf "$sof" -C "$S"
L=$(find "$S" -maxdepth 1 -type d -name 'linux-firmware-*' | head -1)
SB=$(find "$S" -maxdepth 1 -type d -name 'sof-bin-*' | head -1)
F="$T/lib/firmware"

# linux-firmware keeps some blobs behind symlinks (WHENCE "Link:"); copy the
# dereferenced files so every requested name exists.
pick() { # paths relative to the linux-firmware tree (globs allowed)
    for pat in "$@"; do
        for p in $L/$pat; do
            [ -e "$p" ] || continue
            rel=${p#"$L"/}
            mkdir -p "$F/$(dirname "$rel")"
            cp -rL "$p" "$F/$rel"
        done
    done
}

# WiFi
pick 'iwlwifi-*' 'intel/iwlwifi' ath9k_htc ath10k ath11k ath12k rtw88 rtw89 'rtlwifi' \
     'mediatek/WIFI_*' 'mediatek/mt7*' 'brcm/brcmfmac*' 'cypress' regulatory.db regulatory.db.p7s
# Bluetooth
pick 'intel/ibt-*' rtl_bt 'mediatek/BT_*' qca 'brcm/*.hcd'
# Ethernet
pick rtl_nic
# GPUs: Intel GuC/HuC/DMC, AMD, older ATI, NVIDIA (without the huge GSP images)
pick i915 amdgpu radeon
for d in "$L"/nvidia/*; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    mkdir -p "$F/nvidia/$n"
    (cd "$d" && find . \( -path './gsp' -o -path './gsp/*' \) -prune -o -print | while IFS= read -r x; do
        [ "$x" = . ] && continue
        if [ -d "$x" ]; then mkdir -p "$F/nvidia/$n/$x"; else cp -L "$x" "$F/nvidia/$n/$x"; fi
    done)
done
# Sound Open Firmware (Intel DSP audio, 2018+ laptops)
for d in "$SB"/sof* ; do
    [ -d "$d" ] || continue
    mkdir -p "$F/intel"
    cp -rL "$d" "$F/intel/"
done
# licences travel with the blobs
cp "$L"/WHENCE "$L"/LICENCE.* "$L"/LICENSE.* "$F/" 2>/dev/null || :
cp "$SB"/LICENCE* "$F/intel/" 2>/dev/null || :

# zstd every blob (not licences, not regulatory.db which cfg80211 reads raw)
find "$F" -type f ! -name 'LICEN*' ! -name WHENCE ! -name 'regulatory.db*' ! -name '*.zst' \
    -exec zstd -q -19 -T0 --rm {} \;
echo "firmware: $(find "$F" -type f | wc -l) files, $(du -sh "$F" | cut -f1)"
(cd "$T" && tar -cf - lib/firmware | xz -T0 -6 > "$OUT")
echo "build-firmware: $OUT ($(du -h "$OUT" | cut -f1))"

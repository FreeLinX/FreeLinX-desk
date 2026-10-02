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
# the WiFi regulatory database (signed; the kernel checks it against the
# wireless-regdb key it carries) - linux-firmware no longer includes it
REGDB_VER="${REGDB_VER:-2026.09.03}"
REGDB_SHA="b22e0901227b820cd1c280abe681a15b773a5103a5e10dc442e94ebb34cbf58d"
KVER="${KVER:-6.18.54}"
OUT="$TOP/firmware-$KVER.tar.xz"
IWL_MAX="${IWL_MAX:-100}"

lfw="$DIST/linux-firmware-$LFW_VER.tar.xz"
[ -f "$lfw" ] || curl -fL -o "$lfw" "https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-$LFW_VER.tar.xz"
echo "$LFW_SHA  $lfw" | sha256sum -c -
sof="$DIST/sof-bin-$SOF_VER.tar.gz"
[ -f "$sof" ] || curl -fL -o "$sof" "https://github.com/thesofproject/sof-bin/releases/download/v$SOF_VER/sof-bin-$SOF_VER.tar.gz"

S="$W/fw-src"; T="$W/fw-stage"
rm -rf "$S" "$T"; mkdir -p "$S" "$T/lib/firmware"
tar -xJf "$lfw" -C "$S"
tar -xzf "$sof" -C "$S"
regdb="$DIST/wireless-regdb-$REGDB_VER.tar.xz"
[ -f "$regdb" ] || curl -fL -o "$regdb" "https://mirrors.edge.kernel.org/pub/software/network/wireless-regdb/wireless-regdb-$REGDB_VER.tar.xz"
echo "$REGDB_SHA  $regdb" | sha256sum -c -
tar -xJf "$regdb" -C "$S"
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
pick 'iwlwifi-*' ath9k_htc ath10k ath11k ath12k rtw88 rtw89 'rtlwifi' \
     'mediatek/WIFI_*' 'mediatek/mt76*' 'mediatek/mt7925' 'brcm/brcmfmac*' 'cypress' regulatory.db regulatory.db.p7s
# Bluetooth
pick 'intel/ibt-*' rtl_bt 'mediatek/BT_*' qca 'brcm/*.hcd'
# Ethernet
pick rtl_nic
# GPUs: Intel GuC/HuC/DMC, AMD, older ATI, NVIDIA (without the huge GSP images)
pick i915 xe amdgpu radeon
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
# linux-firmware keeps iwlwifi under intel/iwlwifi; the kernel asks for
# iwlwifi-*.ucode at the top level and loads at most API $IWL_MAX (linux
# 6.18; iwlmld drives the Wi-Fi 7 parts).  Ship only the newest usable
# version per device (plus the .pnvm tables).  MediaTek's Wi-Fi 7 MT7996 and
# MT7927 have no driver in this kernel and are not shipped.
for f in "$L"/intel/iwlwifi/iwlwifi-* "$F"/intel/iwlwifi/iwlwifi-*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    case "$b" in
        *.pnvm) cp -L "$f" "$F/$b" ;;
        *.ucode)
            v=$(echo "$b" | sed -n 's/.*-\([0-9][0-9]*\)\.ucode$/\1/p')
            [ -n "$v" ] && [ "$v" -le "$IWL_MAX" ] && cp -L "$f" "$F/$b" ;;
    esac
done
(cd "$F" && ls iwlwifi-*.ucode 2>/dev/null | sed -E 's/-([0-9]+)\.ucode$/ \1/' | sort -k1,1 -k2,2n |
    awk '{v[$1]=v[$1]" "$2; m[$1]=$2} END {for (k in v) {n=split(v[k],a," "); for (i=1;i<=n;i++) if (a[i]!=m[k]) print k"-"a[i]".ucode"}}' |
    xargs rm -f)
rm -rf "$F/intel/iwlwifi" "$F/mediatek/mt7996" "$F/mediatek/mt7927"
R="$S/wireless-regdb-$REGDB_VER"
cp "$R/regulatory.db" "$R/regulatory.db.p7s" "$F/"
cp "$R/LICENSE" "$F/LICENSE.wireless-regdb"
# licences travel with the blobs
cp "$L"/WHENCE "$L"/LICENCE.* "$L"/LICENSE.* "$F/" 2>/dev/null || :
cp "$SB"/LICENCE* "$F/intel/" 2>/dev/null || :

# zstd every blob (not licences, not regulatory.db which cfg80211 reads raw)
find "$F" -type f ! -name 'LICEN*' ! -name WHENCE ! -name 'regulatory.db*' ! -name '*.zst' \
    -exec zstd -q -19 -T0 --rm {} \;
echo "firmware: $(find "$F" -type f | wc -l) files, $(du -sh "$F" | cut -f1)"
(cd "$T" && tar -cf - lib/firmware | xz -T0 -6 > "$OUT")
echo "build-firmware: $OUT ($(du -h "$OUT" | cut -f1))"

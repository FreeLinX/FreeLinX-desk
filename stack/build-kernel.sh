#!/bin/sh
# FreeLinX Desktop - kernel + modules with the FreeLinX LLVM toolchain
#
# Builds linux-$KVER (6.18 LTS) from the pristine kernel.org tarball with kernel/kernel.config (or
# an existing $STACK_WORK/build/kernel/.config), then installs kernel/bzImage,
# kernel/kernel.config and src/rootfs/lib/modules/<kver>.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
# kernel.org 6.18 LTS; the tarball is checked against kernel.org's sha256sums
KVER="${KVER:-6.18.54}"
KSHA="${KSHA:-9df30b02dd8102bbd0be52556288ef6889ddbe7f1ddb96fbf847d0becf3eacac}"
TARBALL="${KERNEL_TARBALL:-$TOP/../kernel/linux-$KVER.tar.xz}"
K="$W/src/linux/linux-$KVER"
O="$W/build/kernel-$KVER"
JOBS="${JOBS:-$(nproc)}"
export PATH="$TC/bin:$PATH"
MK="make -C $K O=$O LLVM=1 LLVM_IAS=1 ARCH=x86_64 KBUILD_BUILD_USER=FreeLinX KBUILD_BUILD_HOST=FreeLinX"

[ -f "$TARBALL" ] || curl -fL -o "$TARBALL" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KVER.tar.xz"
echo "$KSHA  $TARBALL" | sha256sum -c - >/dev/null
if [ ! -d "$K" ]; then
    mkdir -p "$W/src/linux"
    tar -xf "$TARBALL" -C "$W/src/linux"
fi
mkdir -p "$O"
[ -f "$O/.config" ] || cp "$TOP/kernel/kernel.config" "$O/.config"
$MK olddefconfig
$MK -j"$JOBS" bzImage modules
cp "$O/arch/x86/boot/bzImage" "$TOP/kernel/bzImage"
cp "$O/.config" "$TOP/kernel/kernel.config"
M="$W/kmod"; rm -rf "$M"
$MK INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH="$M" modules_install
kver=$(ls "$M/lib/modules")
rm -f "$M/lib/modules/$kver/build" "$M/lib/modules/$kver/source"
# only this kernel's modules ship
rm -rf "$TOP"/src/rootfs/lib/modules/*
cp -a "$M/lib/modules/$kver" "$TOP/src/rootfs/lib/modules/$kver"
echo "build-kernel: $(strings "$O/vmlinux" | grep -m1 'Linux version' | cut -c1-90)"

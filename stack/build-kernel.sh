#!/bin/sh
# FreeLinX Desktop - kernel + modules with the FreeLinX LLVM toolchain
#
# Builds linux-6.6.21 from the pristine tarball with kernel/kernel.config (or
# an existing $STACK_WORK/build/kernel/.config), then installs kernel/bzImage,
# kernel/kernel.config and src/rootfs/lib/modules/<kver>.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
TARBALL="${KERNEL_TARBALL:-$TOP/../kernel/linux-6.6.21.tar.xz}"
K="$W/src/linux/linux-6.6.21"
O="$W/build/kernel"
JOBS="${JOBS:-$(nproc)}"
export PATH="$TC/bin:$PATH"
MK="make -C $K O=$O LLVM=1 LLVM_IAS=1 ARCH=x86_64 KBUILD_BUILD_USER=FreeLinX KBUILD_BUILD_HOST=FreeLinX"

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
rm -rf "$TOP/src/rootfs/lib/modules/$kver"
cp -a "$M/lib/modules/$kver" "$TOP/src/rootfs/lib/modules/$kver"
echo "build-kernel: $(strings "$O/vmlinux" | grep -m1 'Linux version' | cut -c1-90)"

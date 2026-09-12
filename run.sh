#!/bin/sh
# FreeLinX Desktop - Launch in QEMU/KVM
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

KERNEL="${SCRIPT_DIR}/kernel/bzImage"
INITRD="${SCRIPT_DIR}/src/build/x86_64/freelinx-desktop.img.gz"

if [ ! -f "$INITRD" ]; then
    INITRD="${SCRIPT_DIR}/src/build/freelinx-desktop.img.gz"
fi

if [ ! -f "$INITRD" ]; then
    echo "Initramfs image not found. Building image from src/rootfs..."
    "${SCRIPT_DIR}/build-image.sh"
fi

DISPLAY_OPT="-display gtk"
if [ "${HEADLESS:-0}" = "1" ]; then
    DISPLAY_OPT="-display none"
fi

ACCEL_OPT="-enable-kvm -cpu host"
if [ ! -w /dev/kvm ] 2>/dev/null; then
    echo "Notice: /dev/kvm not accessible, falling back to emulation"
    ACCEL_OPT=""
fi

exec qemu-system-x86_64 \
  $ACCEL_OPT \
  -smp 4 -m 1280 \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  -vga virtio \
  -device virtio-tablet-pci \
  -nic user,model=virtio-net-pci \
  $DISPLAY_OPT \
  "$@"

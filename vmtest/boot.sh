#!/bin/sh
# FreeLinX - boot the desktop initramfs under QEMU/KVM
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
KERNEL="${SCRIPT_DIR}/kernel/bzImage"
INITRD="${SCRIPT_DIR}/src/build/x86_64/freelinx-desktop.img.gz"

if [ ! -f "$INITRD" ]; then
    INITRD="${SCRIPT_DIR}/src/build/freelinx-desktop.img.gz"
fi

[ -f "$KERNEL" ] || { echo "missing $KERNEL"; exit 1; }
[ -f "$INITRD" ] || { echo "missing $INITRD"; exit 1; }

mkdir -p "${SCRIPT_DIR}/vmtest"
rm -f "${SCRIPT_DIR}/vmtest/serial.log" "${SCRIPT_DIR}/vmtest/screen.ppm"
: > "${SCRIPT_DIR}/vmtest/serial.log"

ACCEL_OPT="-enable-kvm -cpu host"
if [ ! -w /dev/kvm ] 2>/dev/null; then
    ACCEL_OPT=""
fi

nohup qemu-system-x86_64 \
    $ACCEL_OPT \
    -smp 4 -m 1280 \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
    -vga virtio \
    -device virtio-tablet-pci \
    -monitor tcp:127.0.0.1:4445,server,nowait \
    -serial file:"${SCRIPT_DIR}/vmtest/serial.log" \
    -display none -no-reboot \
    > "${SCRIPT_DIR}/vmtest/qemu.log" 2>&1 &
echo $! > "${SCRIPT_DIR}/vmtest/qemu.pid"
echo "QEMU pid $(cat "${SCRIPT_DIR}/vmtest/qemu.pid")"

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
VGA_DEVICE="-vga virtio"

if [ "${HEADLESS:-0}" = "1" ]; then
    DISPLAY_OPT="-display none"
else
    # Automatically enable hardware OpenGL display rendering (60+ FPS) if supported
    if [ "${GL:-1}" != "0" ] && [ "${NOGL:-0}" != "1" ]; then
        if qemu-system-x86_64 -display gtk,gl=on -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display gtk,gl=on"
        elif qemu-system-x86_64 -display sdl,gl=on -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display sdl,gl=on"
        fi

        # Enable VirGL hardware 3D GPU acceleration if supported
        if qemu-system-x86_64 -device virtio-vga-gl -display none -help >/dev/null 2>&1; then
            VGA_DEVICE="-device virtio-vga-gl"
            echo "Hardware 3D Acceleration: Active (VirGL / virtio-vga-gl)"
        fi
    fi
fi

ACCEL_OPT="-enable-kvm -cpu host"
if [ ! -w /dev/kvm ] 2>/dev/null; then
    echo "Notice: /dev/kvm not accessible, falling back to emulation"
    ACCEL_OPT=""
fi

echo "Starting FreeLinX Desktop (QEMU/KVM)..."
exec qemu-system-x86_64 \
  $ACCEL_OPT \
  -smp 4 -m "${RAM:-2048}" \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  $VGA_DEVICE \
  -device virtio-tablet-pci \
  -nic user,model=virtio-net-pci \
  -serial stdio \
  $DISPLAY_OPT \
  "$@"

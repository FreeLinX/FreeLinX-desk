#!/bin/sh
# FreeLinX Desktop - Universal QEMU / KVM Launch Script
# Portable across any machine, host Linux distro, nested VM, or bare-metal environment.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL="${SCRIPT_DIR}/kernel/bzImage"
INITRD="${SCRIPT_DIR}/src/build/x86_64/freelinx-desktop.img.gz"

if [ ! -f "$INITRD" ]; then
    INITRD="${SCRIPT_DIR}/src/build/freelinx-desktop.img.gz"
fi

if [ ! -f "$INITRD" ]; then
    echo "[FreeLinX] Initramfs image not found. Building image from src/rootfs..."
    "${SCRIPT_DIR}/build-image.sh"
fi

QEMU_BIN="qemu-system-x86_64"
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "[FreeLinX][error] qemu-system-x86_64 is not installed or not in PATH." >&2
    exit 1
fi

# ── 1. Virtualization Acceleration (KVM vs Emulation) ────────────────────────
ACCEL_OPT="-enable-kvm -cpu host"
if [ ! -w /dev/kvm ] 2>/dev/null || ! "$QEMU_BIN" -enable-kvm -help >/dev/null 2>&1; then
    echo "[FreeLinX] Notice: /dev/kvm acceleration not available; falling back to software emulation."
    ACCEL_OPT="-cpu qemu64"
fi

# ── 2. Display Backend Probing (GTK, SDL, VirGL 3D, Curses, Headless) ─────────
DISPLAY_OPT=""
VGA_DEVICE="-vga virtio"

if [ "${HEADLESS:-0}" = "1" ]; then
    DISPLAY_OPT="-display none"
elif [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "[FreeLinX] Notice: No graphical display server detected (DISPLAY/WAYLAND_DISPLAY not set)."
    echo "[FreeLinX] Falling back to text console display (-display curses)."
    DISPLAY_OPT="-display curses"
else
    # Host has graphical server active; probe hardware GL & windowing backends
    if [ "${GL:-1}" != "0" ] && [ "${NOGL:-0}" != "1" ]; then
        if "$QEMU_BIN" -display gtk,gl=on -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display gtk,gl=on"
        elif "$QEMU_BIN" -display sdl,gl=on -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display sdl,gl=on"
        fi

        if "$QEMU_BIN" -device virtio-vga-gl -display none -help >/dev/null 2>&1; then
            VGA_DEVICE="-device virtio-vga-gl"
            echo "[FreeLinX] Hardware 3D Acceleration: Active (VirGL / virtio-vga-gl)"
        fi
    fi

    # Fallback to software 2D display if GL display is disabled/unsupported
    if [ -z "$DISPLAY_OPT" ]; then
        if "$QEMU_BIN" -display gtk -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display gtk"
        elif "$QEMU_BIN" -display sdl -help >/dev/null 2>&1; then
            DISPLAY_OPT="-display sdl"
        elif "$QEMU_BIN" -display default -help >/dev/null 2>&1; then
            DISPLAY_OPT=""
        else
            DISPLAY_OPT="-display curses"
        fi
    fi
fi

# ── 3. Audio Emulation (Intel HDA / ALSA guest support) ───────────────────────
AUDIO_OPT="-device ich9-intel-hda -device hda-duplex"
if [ "${NOAUDIO:-0}" = "1" ]; then
    AUDIO_OPT=""
fi

echo "[FreeLinX] Starting FreeLinX Desktop (QEMU/KVM)..."
exec "$QEMU_BIN" \
  $ACCEL_OPT \
  -smp "${CPUS:-4}" -m "${RAM:-2048}" \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  $VGA_DEVICE \
  -device virtio-tablet-pci \
  -nic user,model=virtio-net-pci \
  $AUDIO_OPT \
  -serial stdio \
  $DISPLAY_OPT \
  "$@"

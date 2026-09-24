#!/bin/sh
# FreeLinX Desktop - QEMU / KVM launch script
# Env knobs: RAM=2048 (min 1400) CPUS=4 HEADLESS=1 GL=1 NOAUDIO=1
#   FLX_DESKTOP=gui|headless  FLX_AUTOLOGIN=1|0  FLX_DISK=disk.img
#   FLX_ISO=file.iso  UEFI=1  FLX_INITRD=path  FLX_BOOT_DISK=1
# Extra arguments are passed to QEMU unchanged.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL="${SCRIPT_DIR}/kernel/bzImage"
INITRD="${FLX_INITRD:-${SCRIPT_DIR}/src/build/x86_64/freelinx-desktop.img.gz}"
RAM="${RAM:-2048}"
CPUS="${CPUS:-4}"

QEMU_BIN="qemu-system-x86_64"
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "[FreeLinX][error] qemu-system-x86_64 is not installed or not in PATH." >&2
    exit 1
fi

if [ -z "${FLX_ISO:-}" ] && [ "${FLX_BOOT_DISK:-0}" != "1" ] && [ ! -f "$INITRD" ]; then
    echo "[FreeLinX] Initramfs image not found. Building image from src/rootfs..."
    "${SCRIPT_DIR}/build-image.sh"
fi

if [ "$RAM" -lt 1400 ] 2>/dev/null; then
    echo "[FreeLinX][warn] RAM=${RAM}MB is too small: the initramfs will fail to unpack. Use RAM>=1400." >&2
fi

have_display() { "$QEMU_BIN" -display help 2>&1 | grep -qw "$1"; }
have_device()  { "$QEMU_BIN" -device help  2>&1 | grep -q "\"$1\""; }

# Acceleration
if [ -w /dev/kvm ]; then
    set -- "$@" -enable-kvm -cpu host
else
    echo "[FreeLinX] Notice: /dev/kvm not usable; falling back to software emulation (slow)."
    set -- "$@" -cpu qemu64
fi
set -- "$@" -smp "$CPUS" -m "$RAM"

# Display
VGA_DEV="virtio-vga"
if [ "${HEADLESS:-0}" = "1" ]; then
    set -- "$@" -display none
elif [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "[FreeLinX] Notice: no DISPLAY/WAYLAND_DISPLAY; running headless (serial console on this terminal)."
    set -- "$@" -display none
else
    if [ "${GL:-0}" = "1" ] && have_device virtio-vga-gl && have_display gtk; then
        VGA_DEV="virtio-vga-gl"; set -- "$@" -display gtk,gl=on
    elif have_display gtk; then
        set -- "$@" -display gtk
    elif have_display sdl; then
        set -- "$@" -display sdl
    fi
fi
set -- "$@" -device "$VGA_DEV" -device virtio-tablet-pci -nic user,model=virtio-net-pci

# Audio
if [ "${NOAUDIO:-0}" != "1" ]; then
    set -- "$@" -device ich9-intel-hda -device hda-duplex
fi

# Optional disk / UEFI
if [ -n "${FLX_DISK:-}" ]; then
    set -- "$@" -drive "file=${FLX_DISK},format=raw,if=virtio"
fi
if [ "${UEFI:-0}" = "1" ]; then
    OVMF=""
    for f in /usr/share/OVMF/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/ovmf/OVMF.fd /usr/share/qemu/OVMF.fd; do
        [ -f "$f" ] && { OVMF="$f"; break; }
    done
    [ -n "$OVMF" ] || { echo "[FreeLinX][error] UEFI=1 but no OVMF firmware found (install 'ovmf')." >&2; exit 1; }
    set -- "$@" -drive "if=pflash,format=raw,readonly=on,file=${OVMF}"
fi

# Boot source
if [ -n "${FLX_ISO:-}" ]; then
    set -- "$@" -cdrom "$FLX_ISO" -boot d
elif [ "${FLX_BOOT_DISK:-0}" = "1" ]; then
    [ -n "${FLX_DISK:-}" ] || { echo "[FreeLinX][error] FLX_BOOT_DISK=1 needs FLX_DISK=<disk image>" >&2; exit 1; }
    set -- "$@" -boot c
else
    CMDLINE="console=ttyS0,115200 rdinit=/init quiet loglevel=2"
    CMDLINE="$CMDLINE flx.desktop=${FLX_DESKTOP:-gui} flx.autologin=${FLX_AUTOLOGIN:-1}"
    set -- "$@" -kernel "$KERNEL" -initrd "$INITRD" -append "$CMDLINE"
fi

echo "[FreeLinX] Starting FreeLinX Desktop (QEMU)..."
exec "$QEMU_BIN" "$@" -serial stdio

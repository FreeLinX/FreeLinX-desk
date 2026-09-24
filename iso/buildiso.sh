#!/bin/sh
# Build a bootable hybrid (BIOS + UEFI) live/installer ISO -> iso/freelinx-desktop.iso
# Host needs: xorriso, git, make + cc, and what build-image.sh needs.
# Env: OUT=path.iso SERIAL=1 LIMINE_REF=v11.4.1-binary LIMINE_DIR=dir FLX_CMDLINE_EXTRA="..."
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-${ROOT_DIR}/iso/freelinx-desktop.iso}"
KERNEL="${FLX_KERNEL:-${ROOT_DIR}/kernel/bzImage}"
INITRD="${FLX_INITRD:-${ROOT_DIR}/src/build/x86_64/freelinx-desktop.img.gz}"
LIMINE_REF="${LIMINE_REF:-v11.4.1-binary}"
LIMINE_DIR="${LIMINE_DIR:-${ROOT_DIR}/iso/limine}"
WORK="${ROOT_DIR}/src/build/iso_root"
EXTRA="${FLX_CMDLINE_EXTRA:-}"

die() { echo "Error: $*" >&2; exit 1; }
for t in xorriso git make; do
    command -v "$t" >/dev/null 2>&1 || die "'$t' is required but not installed."
done
[ -f "$KERNEL" ] || die "kernel not found: $KERNEL"
[ -f "$INITRD" ] || "${ROOT_DIR}/build-image.sh"

if [ ! -f "${LIMINE_DIR}/limine-bios-cd.bin" ]; then
    rm -rf "$LIMINE_DIR"
    git clone -q --depth 1 --branch "$LIMINE_REF" https://github.com/limine-bootloader/limine.git "$LIMINE_DIR" \
        || die "could not fetch Limine (offline?)"
fi
[ -x "${LIMINE_DIR}/limine" ] || make -C "$LIMINE_DIR" >/dev/null
for f in limine-bios-cd.bin limine-uefi-cd.bin limine-bios.sys BOOTX64.EFI; do
    [ -f "${LIMINE_DIR}/$f" ] || die "missing ${LIMINE_DIR}/$f"
done

rm -rf "$WORK"
mkdir -p "$WORK/boot/limine" "$WORK/EFI/BOOT"
cp -f "$KERNEL" "$WORK/boot/bzImage"
cp -f "$INITRD" "$WORK/boot/initramfs.img.gz"
cp -f "${LIMINE_DIR}/limine-bios-cd.bin" "${LIMINE_DIR}/limine-uefi-cd.bin" \
      "${LIMINE_DIR}/limine-bios.sys" "$WORK/boot/limine/"
cp -f "${LIMINE_DIR}/BOOTX64.EFI" "$WORK/EFI/BOOT/BOOTX64.EFI"

SERIAL_ARGS=""; SERIAL_CONF=""
[ "${SERIAL:-0}" = "1" ] && { SERIAL_ARGS="console=ttyS0,115200"; SERIAL_CONF="serial: yes"; }
cat > "$WORK/boot/limine/limine.conf" <<CONF
timeout: 5
${SERIAL_CONF}

/FreeLinX Live (Desktop)
    protocol: linux
    kernel_path: boot():/boot/bzImage
    module_path: boot():/boot/initramfs.img.gz
    cmdline: rdinit=/init console=tty0 ${SERIAL_ARGS} quiet loglevel=2 flx.desktop=gui flx.autologin=1 ${EXTRA}

/FreeLinX Live (Text console - run flxinstall)
    protocol: linux
    kernel_path: boot():/boot/bzImage
    module_path: boot():/boot/initramfs.img.gz
    cmdline: rdinit=/init console=tty0 ${SERIAL_ARGS} quiet loglevel=2 ${EXTRA}
CONF

rm -f "$OUT"
xorriso -as mkisofs -quiet -R -r -J -V FREELINX_LIVE \
    -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    -hfsplus -apm-block-size 2048 \
    --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image \
    --protective-msdos-label "$WORK" -o "$OUT"
"${LIMINE_DIR}/limine" bios-install "$OUT"
rm -rf "$WORK"
echo "done: $OUT ($(du -h "$OUT" | cut -f1))"

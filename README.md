# FreeLinX/Desktop

FreeLinX is an independent, non-GNU Linux distribution: NetBSD userland, musl,
LLVM toolchain, runit. This repository holds the **desktop** (Openbox) and the
release image. See [RELEASE-NOTES.md](RELEASE-NOTES.md) for what ships.

The desktop is CPU-rendered (Xorg fbdev with ShadowFB, or modesetting on KMS
dumb buffers), so it needs no GPU driver; input uses `evdev` (keyboard, mouse,
touchpad, and QEMU's `virtio-tablet`).

---

## Running it in QEMU

### Method 1: Using the automated launcher (Recommended)

Run the included launch script directly from the repository root:

```sh
cd ~/FreeLinX/desktop-test
./run.sh
```

`run.sh` automatically:
- Checks if `/dev/kvm` is available and enables hardware acceleration (`-enable-kvm -cpu host`), falling back to software emulation if unavailable.
- Verifies and auto-builds the initramfs if missing.
- Attaches the `virtio-net-pci` user network device and `virtio-tablet-pci` seamless mouse.
- Attaches serial output to `stdio` for debugging.

---

### Method 2: Single-line copy & paste command

To run QEMU directly with a clean, single-line command without any line wraps or backslash issues:

```sh
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 1280 -kernel kernel/bzImage -initrd initrd.img -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" -vga virtio -device virtio-tablet-pci -nic user,model=virtio-net-pci -serial stdio -display gtk
```

> **Note for environments without KVM (nested VMs, containers, etc.):**
> Omit `-enable-kvm -cpu host`:
> ```sh
> qemu-system-x86_64 -smp 4 -m 1280 -kernel kernel/bzImage -initrd initrd.img -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" -vga virtio -device virtio-tablet-pci -nic user,model=virtio-net-pci -serial stdio -display gtk
> ```

---

### Method 3: Multi-line formatted command

```sh
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 4 -m 1280 \
  -kernel kernel/bzImage \
  -initrd initrd.img \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  -vga virtio \
  -device virtio-tablet-pci \
  -nic user,model=virtio-net-pci \
  -serial stdio \
  -display gtk
```

---

### Method 4: Headless Mode (CLI / CI Testing)

To boot and test the system headlessly without opening an X11/GTK display window:

```sh
HEADLESS=1 ./run.sh
```

---

## Network & Web Browsing

- **Ethernet** comes up at boot (`dhcpcd`; under QEMU a static
  `10.0.2.15/24` user-net config). CA roots: `/etc/ssl/certs/ca-certificates.crt`.
- **Browsers**: Firefox ESR (panel launcher, `flxbrowser`, `x-www-browser`);
  NetSurf, Dillo, Links and w3m from the *Network* menu.
- **Network manager** (`flxnetmgr`, panel/menu): interface state, bring
  up/down, renew DHCP, WiFi scan and connect (`wpa_supplicant`), DNS and ping.
- **Time zone**: *Network → Time Zone…* (`flxtz`), the installer, or
  `flx.tz=Area/City` on the kernel command line.
- **Real WiFi in QEMU**: pass a USB adapter through:
  ```sh
  ./run.sh -device qemu-xhci -device usb-host,vendorid=0xXXXX,productid=0xYYYY
  ```

---

## Desktop Controls & Shortcuts

- **Panel** (bottom): Firefox, terminal, files, network, installer; window
  list; clock.
- **Root menu**: right-click the desktop.
- `Alt + Tab` cycle windows, `Alt + F4` close, `Super + p` / `Alt + F2` run
  (dmenu).

---

## Building

The desktop stack is built by the scripts in `stack/` from pinned sources
(`stack/sources.txt`) with the FreeLinX LLVM toolchain:

```sh
stack/build-stack.sh     # musl sysroot, X11/Xorg/GTK, userland
stack/build-rust.sh      # Linux-PAM, greetd, tuigreet
stack/build-firefox.sh   # Firefox ESR
stack/install-stack.sh   # copy into src/rootfs and run check-nognu.sh
./build-image.sh         # pack the initramfs (fails on GNU/glibc artefacts)
sh iso/buildiso.sh       # hybrid BIOS/UEFI ISO -> iso/freelinx-desktop.iso
```

`kernel/bzImage` is Linux 6.18.54 (LTS) built from `kernel/kernel.config` with the
FreeLinX clang/LLD.

---

## License

BSD 2-Clause, matching `LICENSE` files across the sub-repositories.

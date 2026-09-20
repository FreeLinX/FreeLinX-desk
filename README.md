# FreeLinX/Desktop

FreeLinX is an independent, from-scratch, non-GNU, musl-based Linux distribution. This repository holds the **desktop**.

It boots directly into a classic 90s Openbox desktop:

- **Classic 90s Clearlooks / Motif Theme** — blue gradient titlebars, centered bold titles, and 3D beveled widgets.
- **Graphical Web Browser (`flxbrowser` / `links -g`)** — non-GNU graphical browser statically linked with Cairo, Xlib, and OpenSSL. Features an offline retro welcome portal and DuckDuckGo Lite web search.
- **Graphical Network Manager (`flxnetmgr`)** — native Cairo/Xlib retro desktop application for managing interfaces (`eth0`, `wlan0`), scanning & connecting to real WiFi networks, and testing DNS/gateway latency.
- **Retro File Manager (`fview`)** — custom C file manager displaying retro directory breadcrumbs, columns (`Name`, `Size`, `Type`, `Date Modified`), and double-click to edit files in vim.
- **Dual Terminal Setup** — Top-left window running `uxterm` (`vim .config/openbox/rc.xml` with syntax highlighting), and top-right window with interactive shell prompt.
- **FreeLinX Root Menu** — right-click desktop menu with working applications (`flxbrowser`, `flxnetmgr`, `uxterm`, `fview`, `thunar`, `vim`, `nano`, `w3m`, `pfetch`, `obconf`, `doom`, `man`, `obxprop`, `xeyes`).

The desktop runs smoothly at 60 FPS using software rendering accelerated by `ShadowFB` (`libshadowfb.so` + `libshadow.so`) on virtio framebuffer (`/dev/fb0`), with full `evdev` keyboard and `virtio-tablet` absolute mouse integration.

---

## What is in this repository

| Path               | Contents                                                        |
|--------------------|-----------------------------------------------------------------|
| `initrd.img`       | Short symlink to the runnable initramfs image                   |
| `run.sh`           | Automated launcher to boot the desktop in QEMU/KVM               |
| `kernel/`          | Kernel build configuration, provenance notes, and the `bzImage` |
| `src/`             | Root filesystem template (`rootfs/`) and staging build scripts  |
| `ports/`           | Non-GNU Ports recipes (`base/`, `graphics/`, `x11/`, etc.)      |
| `flxnetmgr.c`     | C source code for FreeLinX Graphical Network Manager            |
| `fview.c`          | C source code for the retro 90s File Manager                   |
| `xeyes.c`          | C source code for FreeLinX standalone mouse tracker             |
| `st-src/`          | Source tree for `st` (built as `uxterm`)                        |
| `build-image.sh`   | Pack the initramfs (`freelinx-desktop.img.gz`) from `src/rootfs`|
| `build-apps.sh`    | Recompile `flxnetmgr`, `fview`, `st`, `xeyes` statically       |
| `vmtest/`          | QEMU boot and test scripts                                      |

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

FreeLinX Desktop provides a fully functional, non-GNU networking stack out of the box:

- **Wired Ethernet (`eth0`)**:
  - Automatically brought up during boot by `/init`.
  - Configured via DHCP (`dhcpcd`) with a fallback static address (`10.0.2.15/24`, gateway `10.0.2.2`).
  - DNS resolution configured in `/etc/resolv.conf` using QEMU's internal proxy (`10.0.2.3`), Cloudflare (`1.1.1.1`), and Google (`8.8.8.8`).
  - Trusted CA root certificates installed at `/etc/ssl/certs/ca-certificates.crt` for HTTPS connections.

- **Graphical Web Browser (`flxbrowser` / `links -g`)**:
  - Launches automatically on boot or from the right-click desktop menu (`Web browser`).
  - Supports full graphical rendering, SSL/TLS encryption, and fast page navigation.
  - Features an embedded DuckDuckGo Lite search form on the welcome page (`/usr/share/freelinx/welcome.html`).
  - Simply type your query and press **Search** to browse the live web.

- **Graphical Network Manager (`flxnetmgr`)**:
  - Docked at the bottom-right corner of the desktop, or launchable from the menu.
  - **Interfaces Tab**: Shows live link state, IP address, and MAC address for all adapters. Includes **Bring UP**, **Take DOWN**, and **Renew DHCP** buttons.
  - **Wireless / WiFi Tab**: Real wireless hardware scanner using `wpa_cli` / Linux wireless extensions. *(Zero mock data — strictly interfaces with physical hardware).*
  - **Tools & DNS Tab**: Displays current Default Gateway, configured DNS resolvers, and provides a real-time **Ping 1.1.1.1** diagnostic test.

- **Real WiFi Hardware Passthrough in QEMU**:
  To use a physical USB WiFi adapter inside the FreeLinX QEMU guest:
  1. Identify the adapter's Vendor ID and Product ID on your host: `lsusb`
  2. Launch QEMU passing the USB device:
     ```sh
     ./run.sh -device qemu-xhci -device usb-host,vendorid=0xXXXX,productid=0xYYYY
     ```

---

## Desktop Controls & Shortcuts

- **Root Menu**: Right-click anywhere on the desktop wallpaper to open the application menu.
- **Mouse Capture**: Seamless absolute pointer integration via `virtio-tablet-pci` (no grab keys required).
- **File Manager (`fview`)**: Navigate files with arrow keys or mouse; double-click or press `Enter` on any text file to edit it in `vim`.
- **Window Management**: Classic Openbox keybindings:
  - `Alt + Tab` — Cycle between open windows.
  - `Alt + F4` — Close current window.
  - `Super + Space` (or right click) — Open root menu.

---

## Building & Packaging

### Repacking the initramfs image

If you edit any files in `src/rootfs/` (such as configurations, scripts, or assets), repack the runnable image with:

```sh
./build-image.sh
```

This creates `src/build/x86_64/freelinx-desktop.img.gz` and refreshes the `initrd.img` symlink.

### Recompiling native C applications

To recompile `flxnetmgr`, `fview`, `st`, and `xeyes` using the static musl-clang toolchain:

```sh
./build-apps.sh
```

---

## Building from Source (Full Toolchain Pipeline)

The complete build pipeline is: **toolchain → ports (userland) → kernel → rootfs → image**.

1. **Toolchain** — static musl cross-toolchain (`clang`/`lld`).
2. **Ports** (`ports/`) — each package under `ports/*/` has a `Makefile` and `distinfo`; sources are fetched into `ports/dist/` and built into staged prefixes under `ports/build/deps/<pkg>/`.
3. **Kernel** (`kernel/`) — built with `kernel/kernel.config`. The pre-built `bzImage` is committed for immediate out-of-the-box booting.
4. **Rootfs & Staging** (`src/`) — `src/scripts/rootfs.sh` and `src/scripts/gui-stage.sh` merge the graphical runtime (Xorg, xkbcomp, Openbox, themes, runit, dbus, libinput quirks) and install the native binaries.
5. **Image Generation** — `src/build/x86_64/freelinx-desktop.img.gz`, consumed by the kernel as the initramfs (`rdinit=/init`).

Detailed architecture documentation is available in `src/README.md`, `src/docs/architecture.md`, `src/docs/openbox-port.md`, `kernel/README.md`, and `ports/`.

---

## License

BSD 2-Clause, matching `LICENSE` files across the sub-repositories.

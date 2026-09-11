# FreeLinX/Desktop

FreeLinX is a from-scratch, musl-based Linux distribution. This repository
holds the **desktop** work: the boot-time graphical stack (X11 + Openbox) and
the small self-contained applications that run on top of it, together with the
kernel configuration, ports recipes, and the root filesystem template used to
build the runnable initramfs.

It boots to a plain black desktop with a right-click Openbox menu:

- **FreeLinX Terminal** — `fterm`, a static Xlib terminal emulator
- **FreeLinX Files** — `fview`, a static Xlib directory browser
- **Window Info** — a terminal running `obxprop`
- **System** sub-menu: `pfetch` system fetch, `w3m` console web browser,
  Openbox reconfigure / restart / log out

The whole desktop runs in software: a minimal X.Org server that draws to a
QEMU `virtio-gpu` framebuffer, supervised by `runit`, with Openbox as the
window manager.

---

## What is in this repository

| Path               | Contents                                                        |
|--------------------|-----------------------------------------------------------------|
| `src/`             | Root filesystem template (`rootfs/`) and the build/stage scripts |
| `kernel/`          | Kernel build configuration, provenance notes, and the `bzImage` |
| `ports/`           | Ports recipes (`base/`, `graphics/`, `x11/`) that build the userland |
| `xpkg/`            | The lightweight package archive tool used by the ports system   |
| `freelinxf/`       | Project specifications and roadmap                              |
| `iso/`             | ISO tooling notes                                               |
| `vmtest/`          | QEMU boot scripts used for testing                              |
| `drivers/`         | In-tree kernel driver work                                      |

Large build artifacts are **not** committed (see `.gitignore`): the
toolchain, the QEMU source tree, upstream source tarballs, and every build
tree (`src/build`, `kernel/build`, `ports/build`, ...). They are produced by
the ports system or fetched on demand.

### The desktop-specific components

- `src/rootfs/var/service/xorg/run` — the `runit` service that starts Xorg
  and the desktop session. It maps the QEMU PS/2 `evdev` nodes to
  `/dev/fl-kbd` and `/dev/fl-pointer`, waits for the X socket, then launches
  Openbox.
- `src/rootfs/etc/xdg/openbox/` — the Openbox menu (`menu.xml`) and session
  `autostart` (plain black background).
- `fterm` / `fview` — built from C sources compiled statically against musl
  and Xlib. Their build recipe is in `src/docs/openbox-port.md`.

### The keyboard note

This build's X server has no functional input stack: the `flkey` driver
registers as the core keyboard but never delivers `KeyPress` events, and the
`XTEST` extension is not usable. Instead of fighting that, `fterm` and
`fview` read the kernel `evdev` node (`/dev/fl-kbd`) directly with a
focus-gated self-feed — they translate Linux keycodes to ASCII / escape
sequences themselves. That is why the apps feel instant and the arrows,
backspace, Enter and Esc all behave normally despite the desktop having no
traditional keyboard path.

---

## Running it

Build the initramfs image from the staged rootfs (see *Building from
source* below for the full pipeline), then boot with QEMU/KVM:

```sh
qemu-system-x86_64 \
  -machine q35,accel=kvm -cpu host -smp 4 -m 1280 \
  -kernel kernel/bzImage -initrd src/build/freelinx-desktop.img.gz \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  -device virtio-gpu-pci -display gtk -vga none -no-reboot \
  -monitor telnet:127.0.0.1:4445,server,nowait \
  -serial file:vmtest/serial.log
```

- Right-click on the black desktop to open the root menu.
- The mouse is a relative device; move it with small deliberate gestures.
- The monitor (`-monitor telnet:127.0.0.1:4445`) can inject keystrokes:
  `sendkey h` etc.

Without KVM, drop `accel=kvm` and `-cpu host`.

After the desktop appears it is a plain black screen: use the right-click
menu to launch **FreeLinX Terminal** or **FreeLinX Files**.

### Packaging the image

`src/build/freelinx-desktop.img.gz` is a gzip'd `newc` cpio initramfs
produced from the staged rootfs (the image itself is not committed):

```sh
cd src/build/x86_64/rootfs && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../freelinx-desktop.img.gz
```

---

## Building from source

The full pipeline is: **toolchain → ports (userland) → kernel → rootfs → image**.

1. **Toolchain** — a static musl cross toolchain (clang/lld). FreeLinX
   builds everything against it; not committed here.
2. **Ports** (`ports/`) — each package under `ports/*/` has a `Makefile`
   and `distinfo`; sources are fetched into `ports/dist/` and built into
   `ports/build/deps/<pkg>/` staged under their configured prefix.
3. **Kernel** (`kernel/`) — built with `kernel/kernel.config`. `bzImage`
   is committed for out-of-the-box booting. Loadable modules go into
   `src/rootfs/lib/modules/`.
4. **Rootfs + stage** (`src/`) — `src/scripts/rootfs.sh` copies the
   template to `src/build/<arch>/rootfs`; `src/scripts/gui-stage.sh`
   merges the graphical runtime (Xorg, xkbcomp, openbox, xkb data, fonts,
   themes, runit, dbus, libinput quirks, ...) and installs the `fterm` /
   `fview` binaries into it. The service scripts and Openbox menu are
   handled there too.
5. **Image** — `src/build/freelinx-desktop.img.gz`, consumed by the kernel
   as the initramfs (`rdinit=/init`).

Full documentation lives in `src/README.md`, `src/docs/architecture.md`,
`src/docs/openbox-port.md`, `kernel/README.md`, and `ports/`.

---

## Design trade-offs (known limitations)

- **Software rendering**: Xorg uses the fbdev path on the virtual
  framebuffer; every repaint is a CPU blit. Animations are minimal and
  windows are deliberately light on chrome. This is a demonstration
  desktop, not a game machine.
- **No image-loading in Openbox**: menus have no icons (compiled without
  image support).
- **Keyboards self-feed** (see above). Num pad keys map to their named
  actions; the standard row is a US layout.
- **Build paths**: several stage scripts bake a host prefix
  (`/home/kanan/FreeLinX-workspace/ports/build/deps/...`) and the runtime
  resolves it with a symlink at build time (see `gui-stage.sh`).

## License

BSD 2-Clause, matching `LICENSE` files in the sub-repositories.

# FreeLinX/Desktop

FreeLinX is a from-scratch, musl-based Linux distribution. This repository
holds the **desktop** work: the boot-time graphical stack (X11 + Openbox) and
the retro 90s desktop environment, together with the kernel configuration,
ports recipes, and the root filesystem template used to build the runnable
initramfs.

It boots to a classic 90s Debian-style Openbox desktop:

- **Classic 90s Clearlooks Theme** — blue gradient titlebars, centered bold titles, and 3D beveled widgets.
- **Top-Left Window** — `uxterm` running `vim .config/openbox/rc.xml` with syntax highlighting and line numbers.
- **Top-Right Window** — `uxterm` terminal session at shell prompt (`erhellt@ganymed:~%`).
- **Bottom-Left Window** — `openbox - File Manager` (`fview`), displaying retro directory breadcrumbs, columns (`Name`, `Size`, `Type`, `Date Modified`), and double-click to edit files in vim.
- **Debian Root Menu** — right-click desktop menu with working applications (`uxterm`, `fview`, `thunar`, `vim`, `nano`, `w3m`, `pfetch`, `obconf`, `doom`, `man`, `obxprop`).

The desktop runs at a silky smooth 60 FPS using software rendering accelerated by `ShadowFB` (`libshadowfb.so` + `libshadow.so`) on virtio framebuffer (`/dev/fb0`), with full `evdev` keyboard and `virtio-tablet` absolute mouse integration.

---

## What is in this repository

| Path               | Contents                                                        |
|--------------------|-----------------------------------------------------------------|
| `src/`             | Root filesystem template (`rootfs/`) and build scripts          |
| `kernel/`          | Kernel build configuration, provenance notes, and the `bzImage` |
| `ports/`           | Ports recipes (`base/`, `graphics/`, `x11/`) that build userland |
| `st-src/`          | Source tree for `st` (built as `uxterm`)                        |
| `fview.c`          | C source code for the retro 90s File Manager                   |
| `run.sh`           | One-click launcher to boot the desktop in QEMU                  |
| `build-image.sh`   | Pack the initramfs (`freelinx-desktop.img.gz`) from `src/rootfs`|
| `build-apps.sh`    | Recompile `fview` and `st` statically against musl              |
| `vmtest/`          | QEMU boot and test scripts                                      |

---

## Running it

To run the desktop OS in QEMU:

```sh
./run.sh
```

Or invoke QEMU directly:

```sh
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 4 -m 1280 \
  -kernel kernel/bzImage \
  -initrd src/build/x86_64/freelinx-desktop.img.gz \
  -append "console=ttyS0,115200 rdinit=/init quiet loglevel=2" \
  -vga virtio \
  -device virtio-tablet-pci \
  -display gtk
```

- Right-click anywhere on the desktop to open the root menu.
- Mouse capture is seamless thanks to `virtio-tablet-pci` (no grab keys needed).
- Double click or press Enter on files in the File Manager to edit them in `uxterm -e vim`.

### Packaging the image

To repack the runnable initramfs image from `src/rootfs`:

```sh
./build-image.sh
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

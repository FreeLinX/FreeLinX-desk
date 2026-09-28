# FreeLinX 1.0 — first release

FreeLinX is an independent Linux distribution with a NetBSD userland, the
musl C library and an LLVM toolchain. **Nothing in the image is built by GCC
or linked against glibc** — every build of the image checks this and refuses
to package a tree that fails (`check-nognu.sh`).

## What you get

- **Openbox desktop** with a bottom panel (launchers, window list, clock with
  time zone), right-click menu, and a CPU-rendered framebuffer path that
  needs no GPU driver.
- **FreeLinX Web** (Firefox ESR 153) for the modern web (full JavaScript), plus NetSurf,
  Dillo, Links and w3m as light browsers.
- **Graphical installer** — language, keyboard, time zone (IANA names, e.g.
  `Asia/Baku`), hostname, root password, user account, WiFi, disk. Installs
  a BIOS + UEFI bootable system (Limine) with persistent `/usr /etc /var` and
  a separate `/home`.
- **Login screen** (greetd + tuigreet) on installed systems; console logins
  on tty1 and the serial port via getty.
- **Network manager** (`flxnetmgr`): interfaces, DHCP, WiFi scan/connect,
  DNS and ping tools; `wheel` users run it without a password prompt.
  `wpa_supplicant`, `dhcpcd`, OpenNTPD.
- **Hardware**: NVMe and SATA disks, Intel (iwlwifi/iwlmvm), Realtek
  (rtw88/rtw89), Atheros, Broadcom and MediaTek MT7921/MT7922 WiFi, HDA
  audio (Realtek, HDMI, Conexant, ...) and USB audio, I2C-HID touchpads,
  exFAT/NTFS/ISO/UDF media.
- Terminal (`st`), file manager (`xfe`), PDF viewer (`mupdf`), media player
  (`mpv`), `vim`/`nvi`, `git`, package manager `xpkg`.

## Under the hood

| Layer | Component |
|---|---|
| Kernel | Linux 6.6.21 LTS, built with FreeLinX clang/LLD 21.1.8 |
| libc | musl 1.2.5 (clang-built) |
| C++ runtime | LLVM libc++ / libc++abi / libunwind 21.1.8 |
| Userland | NetBSD 10.1 tools; toybox (0BSD) for `ps`, `top`, `free`, `uptime`, `pgrep`, `pidof`, `getty`, console `login` |
| Init | runit + mdevd |
| Graphics | Xorg 21.1.24 (fbdev + modesetting, evdev input), GTK 3.24, cairo, pango, harfbuzz |
| Auth | Linux-PAM 1.7 (greetd), shadow SHA-512 |
| Time | IANA tzdata 2026d |

Rust programs (greetd, tuigreet) are built with a from-source Rust standard
library, so rustup's GCC-built musl objects never reach the image.

## Running it

```sh
./run.sh                                   # QEMU/KVM, live desktop
FLX_ISO=iso/freelinx-desktop.iso ./run.sh  # boot the ISO like a CD/USB
```

Write `iso/freelinx-desktop.iso` to a USB stick to boot real hardware
(BIOS or UEFI). Give the machine at least 2 GB of RAM: the live system runs
from memory. Add `flx.tz=Area/City` to the kernel command line to start the
live session in your time zone, or use *Time Zone…* in the Network menu.

## Building

```sh
stack/build-stack.sh     # musl sysroot + X11/Xorg/GTK stack + userland
stack/build-rust.sh      # Linux-PAM, greetd, tuigreet
stack/build-firefox.sh   # Firefox ESR (long: ~2 h on 8 cores)
stack/install-stack.sh   # copy the stack into src/rootfs, run the checks
./build-image.sh         # initramfs (fails on any GNU/glibc artefact)
sh iso/buildiso.sh       # hybrid BIOS/UEFI ISO
```

## Security notes

- The image ships with root **locked**; the installer requires a root
  password. The live ISO logs in automatically as root.
- Installed systems ask for a password on every console and on the login
  screen. `doas` gives members of `wheel` administrator rights.
- Xorg is setuid root (there is no seat manager) and listens only on its
  local socket.

## Known limitations

- No GPU acceleration: rendering is done on the CPU (fbdev / KMS dumb
  buffers). WebGL and video decoding in Firefox run in software.
- `mount` needs an explicit `-t` type; removable media are mounted
  automatically under `/media`.
- Laptops with Intel SOF-only audio (some 2020+ models) may need
  `snd_intel_dspcfg.dsp_driver=1` on the kernel command line.

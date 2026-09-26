# Desktop-test/ports — status: STALE FORK, DO NOT BUILD FROM HERE

## What this is

`Desktop-test/ports/` is a **committed copy of the `FreeLinX/ports` tree**,
not a submodule and not a separate repository. It was vendored into this repo
at some point and has since diverged from the canonical tree in both
directions. Nothing in the desktop build reads it.

## Proof that the build does not use it

`build-apps.sh` compiles `xmag.c`, `xclock.c`, `flxinstall-gui.c` and
`st-src/st.c` directly against the **toolchain sysroot**
(`toolchain/x86_64-linux-musl`), which already carries the prebuilt static
X11/cairo/GTK archives. `build-image.sh` only packs `src/rootfs` with
`cpio`. Neither script references `ports/`, and `grep -rn "ports/" --include=*.sh`
finds no build-time use of it.

## How far it has drifted

Measured against `FreeLinX/ports` (directories holding a `Makefile`):

| | count |
|---|---|
| ports in this fork | 421 |
| ports in `FreeLinX/ports` | 449 |
| **only here** | **97** |
| **only in `FreeLinX/ports`** | **125** |
| shared, byte-identical | 281 |
| shared, differing | 43 |

The 97 that exist only here are the entire desktop stack: `xorg-server` and
~40 `libX*`/`libxcb*`, GTK3, cairo, pango, fontconfig, freetype, harfbuzz,
Wayland + weston, XFCE (`thunar`, `xfconf`, `xfce4-terminal`, `exo`,
`libxfce4util`, `libxfce4ui`), openbox, picom, dunst, tint2, xfe, xinit,
xterm bits, dbus, linux-pam, alsa-lib/alsa-utils, python3, openssl-3.3.2.
They also introduce two categories that do not exist upstream: `xfce/` and
`system/`.

On the 43 shared ports that differ, the drift direction is **upstream is
newer and already fixed**; this copy keeps the older, broken version. Example
— `base/ncurses` here sets its variables and *then* includes
`../../mk/project-port.mk`, but `project-port.mk` simply-expands them at
include time, so they are frozen empty. Upstream moved the include to the end
and documented why. That is the same `:=`-versus-lazy-expansion class of bug
fixed in `mk/base-port.mk`.

## Do not merge the 97 into FreeLinX/ports wholesale

They are unvalidated: this tree never built them (no build path reaches it),
and the shared ports that *were* touched here are demonstrably stale. Copying
them in would import known-buggy recipes. The correct direction is to
re-create the needed desktop ports directly in `FreeLinX/ports`, on top of the
current framework.

## The GUI deps cannot be rebuilt from this repository at all

`src/scripts/gui-stage.sh` stages the GUI runtime out of
`$FREELINX_PORTS_DIR/build/deps`. That directory is gitignored, and the tree
present here contains only:

    cowsay ffmpeg figlet fltk fortune libass libevent libgcrypt libgpg-error
    libnl libpcap libsodium libudev-stub libusb ncurses nnn openpam openssl
    skalibs sndio sqlite xcalc zlib zstd

Every directory the GUI staging actually reads — `x11`, `openbox-3.6.1`,
`libinput`, `gtk-3.24.52`, `thunar-4.20.9`, `linux-pam`, `xkeyboard-config` —
is **absent**. They existed only in the original author's build tree, which is
why `gui-stage.sh` had a hard-coded `/home/kanan/...` prefix: that was not
carelessness, it was the only place those artifacts had ever been built. The
prefix is now overridable via `FLX_BAKED_DEPS_PREFIX`, but overriding it does
not conjure the binaries — the desktop image is currently reproducible only
where that original deps tree still exists.

## Recommendation

1. Keep this directory for now (it is the only record of those 97 recipes) but
   stop treating it as a build input — nothing already does.
2. Re-create the desktop ports in `FreeLinX/ports` as they are actually
   needed, using the current `mk/` framework.
3. Build the GUI deps with a fixed, canonical prefix (e.g. `/usr`) so the
   alias-at-a-baked-path trick in `gui-stage.sh` becomes unnecessary and the
   desktop becomes reproducible by anyone.

# Openbox / X11 desktop on FreeLinX

Goal: a normal, distro-like Openbox desktop running on the static-musl,
non-GNU FreeLinX userland, replacing the Wayland/Weston stack.

## Stack layout

```
X client apps (xfce4-terminal, thunar, ...)
        |
   Openbox 3.6.1          <- window manager, decorations, menus
        |  (cairo-xlib renderer, EWMH, key/mouse grabs, rc.xml/menu.xml)
   cairo (Xlib/XRender/XCB backends)  +  Pango (pangocairo)
        |
   libXft / cairo-xlib / PangoCairo font & text
        |
   libX11 <- libXau/libXdmcp/libxcb (static closure in deps/x11)
        |
      X server  (Xorg: fbdev/shadow on virtio framebuffer)
        |
   Linux kernel (virtio-gpu KMS + DRM fbdev emulation -> /dev/fb0)
```

## Shared X prefix

All X11 libraries (except Openbox and its data) install into one shared tree,
exactly like a distro's `/usr`:

- `ports/build/deps/x11/lib`      -- static archives + `.pc` files
- `ports/build/deps/x11/include`  -- merged headers (xorgproto, Xlib, Xft, Pango shim)
- `ports/build/deps/x11/share/pkgconfig` -- xorgproto's pkgconfig files

The port skeleton generator produced every X port;
each `Makefile` sets `FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11` and a Pure-C
stack (`FLX_PROJECT_LIBS?=`), and `ports/mk/pkgconfig-libdir.mk` appends both
`deps/x11/lib/pkgconfig` and `deps/x11/share/pkgconfig` to `PKG_CONFIG_LIBDIR`
(30 dirs total).

Key static-link lessons learned while building the stack:

1. `libX11.pc` does not list its static dependencies.  It is patched by the
   libX11 port's `BUILD_CMDS` so `Libs: -lX11 -lXau -lXdmcp` -- otherwise every
   static consumer fails with `undefined symbol: XauGetBestAuthByAddr`.
2. Raw autoconf probes (`AC_CHECK_LIB` for `-lX11`, `#include <X11/Xlib.h>`)
   need the `-L deps/x11/lib` and `-I deps/x11/include` on the exported
   `LDFLAGS`/`CFLAGS`/`CPPFLAGS`, and the `-lXau -lXdmcp -lxcb -lpthread`
   closure in `LIBS` (see `ports/x11/openbox-3.6.1/Makefile`).
3. Non-X ports that link libX11 (meson's cairo) pick the `x11` pc *without*
   `--static`; exposing Xau/Xdmcp in `Libs:` (not `Libs.private:`) fixes them.

## pangoxft compatibility shim

Pango 1.56 deleted the pangoxft module; Openbox 3.6.1 still uses three entry
points.  `ports/x11/pangoxft-compat` reimplements them over PangoCairo +
cairo-xlib and installs `include/pango/pangoxft.h`, `lib/libpangoxft.a`, and
`lib/pkgconfig/pangoxft.pc` (Version 1.56.4 >= 1.8.0, `Requires: pangocairo`,
`Requires.private: cairo-xlib xft`).

- `pango_xft_get_context()` -> `pango_cairo_font_map_get_default()` context.
- `pango_xft_render_layout/layout_line()` -> wrap the XftDraw in a
  `cairo_xlib_surface`, convert the 16-bit premultiplied `XftColor` to cairo
  source RGBA, `pango_cairo_show_layout(_line)`, flush.
- The `XftDraw *` doubles as the renderer handle: `typedef XftDraw
  PangoXftRenderer` keeps openbox's `font.c` type-clean.

`pangoxft.pc` requires `pangocairo` rather than `pango` because pango's own
`pango.pc` only `Requires:` (not `Requires.private:`) its Cairo backend, and
openbox's link must pull `-lpangocairo-1.0`.

## Openbox build notes

`ports/x11/openbox-3.6.1` (GPL-2.0):
- `--disable-pyconify --disable-dbus --disable-startup-notification
  --disable-session-management`.
- Bundled `config.sub` predates `*-linux-musl`; copies the host automake 1.18
  `config.{sub,guess}` into the tree before `./configure`.
- A stale obrender `.la` kept old `PANGO_LIBS`; removing `obrender/.libs` and
  relinking regenerates it with `-lpangocairo-1.0`.
- Artifacts: `deps/openbox-3.6.1/bin/{openbox,obxprop,openbox-session,...}`
  plus `share/{themes,applications,xsessions}` and `etc/xdg/openbox/`.

## The eight requested components

1. **X11 event loop** -- openbox's `openbox/event.c` (select/readblocked X
   connection), client/root/leave map, config reload on `SIGHUP`.
2. **Focus + stacking** -- `openbox/focus.c` (focus-follows-mouse modes,
   sloppy below/above, focus targets), `openbox/stacking.c` (layer 0..15,
   `_NET_WM_WINDOW_TYPE_*` mapping), `focus_cycle.c` (alt-tab indicators).
3. **rc.xml / menu.xml** -- libxml2 `parse.c`, `config.c`; tree walks generate
   actions (ACT_EXECUTE, ACT_MOVE, ...) from `<action>` elements; `menu.xml`
   loads `applications/` and `menu.xml` entries, `.desktop`-derived show.
4. **Bindings** -- `grab.c` `XGrabKey`/`XGrabButton`; `keyboard.c`/`mouse.c`
   translate X keycodes/button events to `<keybind>`/`<mousebind>` actions,
   root-window vs client-window contexts.
5. **Root menu / pipe menus** -- `openbox/menu.c` + `menuframe.c`; pipe
   (`<menu execute="">`) commands via `(parse_reply)` streaming in
   `menu.c` (`%%FONT`, `%%CONSOLE`, `%%TERMINAL` replacements).
6. **Themes** -- `obrender/render.{c,h}`, `obrender/theme.c` parse the
   Openbox theme format (title, handles, buttons) into `RrBorderLayout` etc.,
   rendered with our `cairo-xlib` renderer; `tools/obtheme` pairing.
7. **EWMH** -- `openbox/screen.c`/`client.c` set and read `_NET_WM_*` props;
   `_NET_CLIENT_LIST`, `_NET_CURRENT_DESKTOP`, `_NET_WM_STATE_*`, pager
   favourites, `_NET_ACTIVE_WINDOW`.
8. **Session / autostart** -- `openbox-session` script, `autostart.sh`,
   `dbus-launch`, `~/.config/openbox` precedence; `--replace` hand-off for a
   future lock screen.

## Remaining work

- **X server**: port xorg-server (fbdev + shadow, no DRM/glamor/Mesa) statically.
  The kernel currently has NO fbdev emulation (`CONFIG_DRM_FBDEV_EMULATION` is
  off) and no VGA framebuffer drivers; virtio-gpu KMS alone gives no `/dev/fb0`.
  Enable `CONFIG_DRM_FBDEV_EMULATION=y` in `kernel/kernel.config`, rebuild the
  kernel, then build xorg-server with the `fbdev` (fbserver) driver on
  `-device virtio-vga` so `openbox` gets a real screen.
- Stage the X server + openbox into the guest (`/var/service/x` under runit or
  an openbox-session init), ship rc.xml/menu.xml/autostart.
- Verify in the VM (SDL display), then optionally attempt full Xorg modesetting.
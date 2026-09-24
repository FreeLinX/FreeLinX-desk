#!/bin/sh
# shellcheck source=common.sh
# gui-stage.sh - merge the graphical (X11/Openbox) runtime into the staged rootfs.
#
# Consumes the artifacts produced by the ports system (build tree under
# <ports>/build/deps/*) and the FreeLinX toolchain sysroot, and merges only the
# RUNTIME pieces (no headers, no .a archives) into the staged root
# filesystem that the ISO repository later packages.  Safe to run more than
# once; files are overwritten in place.
#
# Everything here is generated/built; nothing is written back into the
# source template in the repository rootfs/.

set -eu

. "$(dirname "$0")/common.sh"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -a) FREELINX_ARCH=$2; shift 2 ;;
        -c) FREELINX_CONFIG=$2; shift 2 ;;
        -h|--help) freelinx_usage; exit 0 ;;
        *) freelinx_die "unknown option: $1 (see -h)" ;;
    esac
done

freelinx_resolve_config
freelinx_load_config

DEPS="${FREELINX_PORTS_DIR}/build/deps"
SYSROOT="${FREELINX_TOOLCHAIN_DIR}/x86_64-linux-musl"
ROOT="${FREELINX_STAGE_ROOTFS}"

freelinx_info "Staging graphical runtime into: $ROOT"

[ -d "$DEPS" ] || freelinx_die "ports deps tree not found: $DEPS (run the ports build first)"
[ -d "$ROOT" ] || freelinx_die "staged rootfs not found: $ROOT (run rootfs.sh first)"

# --- X keyboard configuration data (rules/keycodes/symbols) ----------------
# Kept (xkeyboard-config) - shared by both libxkbcommon and Xorg.
if [ -d "$DEPS/xkeyboard-config/share/X11/xkb" ]; then
    mkdir -p "$ROOT/usr/share/X11"
    cp -a "$DEPS/xkeyboard-config/share/X11/xkb" "$ROOT/usr/share/X11/"
fi

# --- fontconfig configuration + data ----------------------------------------
# fonts.conf is compiled in as /etc/fonts/fonts.conf; conf.d symlinks and the
# conf.avail sources are both data for the runtime tree.
if [ -d "$DEPS/fontconfig/etc/fonts" ]; then
    mkdir -p "$ROOT/etc"
    cp -a "$DEPS/fontconfig/etc/fonts" "$ROOT/etc/"
    mkdir -p "$ROOT/usr/share/fontconfig"
    cp -a "$DEPS/fontconfig/share/fontconfig/conf.avail" "$ROOT/usr/share/fontconfig/"
fi
mkdir -p "$ROOT/var/cache/fontconfig"

# --- fonts (dejavu) ---------------------------------------------------------
if [ -d "$DEPS/dejavu-fonts/usr/share/fonts" ]; then
    mkdir -p "$ROOT/usr/share/fonts"
    cp -a "$DEPS/dejavu-fonts/usr/share/fonts/." "$ROOT/usr/share/fonts/"
fi

# --- cursor theme (adwaita cursors) -----------------------------------------
if [ -d "$DEPS/adwaita-cursors/usr/share/icons" ]; then
    mkdir -p "$ROOT/usr/share/icons"
    cp -a "$DEPS/adwaita-cursors/usr/share/icons/." "$ROOT/usr/share/icons/"
fi

# --- runit supervision suite ------------------------------------------------ 
if [ -d "$DEPS/runit/sbin" ]; then
    cp -a "$DEPS/runit/sbin/." "$ROOT/sbin/"
fi
if [ -d "$DEPS/runit/usr/bin" ]; then
    mkdir -p "$ROOT/usr/bin"
    cp -a "$DEPS/runit/usr/bin/." "$ROOT/usr/bin/"
fi

# --- musl dynamic loader + libc + C++ runtime DSOs ---------------------------
mkdir -p "$ROOT/lib"
cp -a "$SYSROOT/lib/libc.so" "$ROOT/lib/libc.so"
ln -sf libc.so "$ROOT/lib/ld-musl-${FREELINX_ARCH}.so.1"
if [ -d "${FREELINX_TOOLCHAIN_DIR}/lib/x86_64-unknown-linux-musl" ]; then
    cp -a "${FREELINX_TOOLCHAIN_DIR}/lib/x86_64-unknown-linux-musl"/lib*.so* "$ROOT/lib/" 2>/dev/null || true
fi

# --- shared runtime libraries (the few DSOs the libweston-era stack needs) ----
# libinput still ships as a shared object; keep it for reuse once X's
# evdev/input stack lands. Other deps are linked statically.
if [ -d "$DEPS/libinput/lib" ]; then
    mkdir -p "$ROOT/usr/lib"
    cp -a "$DEPS/libinput/lib"/libinput.so* "$ROOT/usr/lib/"
fi

# --- libinput device-quirks data + build-prefix alias ------------------------
# libinput is configured with prefix=${DEPS}/libinput, so its compiled-in
# quirks search path is an absolute host path baked at build time.  We (1)
# stage the quirks data tree at the canonical /usr/share/libinput, and (2)
# create a live alias at that baked path so the guest resolves it to
# /usr/share/libinput without rebuilding libinput.
if [ -d "$DEPS/libinput/share/libinput" ]; then
    mkdir -p "$ROOT/usr/share/libinput"
    cp -a "$DEPS/libinput/share/libinput/." "$ROOT/usr/share/libinput/"
    bake_pfx="/home/kanan/FreeLinX-workspace/ports/build/deps/libinput"
    mkdir -p "$ROOT$bake_pfx/share"
    ln -sfn /usr/share/libinput "$ROOT$bake_pfx/share/libinput"
fi

# --- GTK3 runtime data (themes needed for client-side decorations) -----------
if [ -d "$DEPS/gtk-3.24.52/share/themes" ]; then
    mkdir -p "$ROOT/usr/share/themes"
    cp -a "$DEPS/gtk-3.24.52/share/themes/." "$ROOT/usr/share/themes/"
fi

# --- Linux-PAM runtime --------------------------------------------------------
if [ -d "$DEPS/linux-pam/lib" ]; then
    mkdir -p "$ROOT/lib"
    cp -a "$DEPS/linux-pam/lib"/libpam*.so* "$ROOT/lib/" 2>/dev/null || true
fi

if [ -d "$DEPS/linux-pam/lib/security" ]; then
    mkdir -p "$ROOT/lib/security"
    cp -a "$DEPS/linux-pam/lib/security"/. "$ROOT/lib/security/"
fi

if [ -f "$DEPS/linux-pam/sbin/unix_chkpwd" ]; then
    mkdir -p "$ROOT/usr/sbin"
    cp -a "$DEPS/linux-pam/sbin/unix_chkpwd" "$ROOT/usr/sbin/"
fi

if [ -f "$DEPS/linux-pam/usr/sbin/unix_chkpwd" ]; then
    mkdir -p "$ROOT/usr/sbin"
    cp -a "$DEPS/linux-pam/usr/sbin/unix_chkpwd" "$ROOT/usr/sbin/"
fi




# --- dbus (daemon, tools, session/system config, bus services) ---------------
if [ -d "$DEPS/dbus-1.16.2/usr/bin" ]; then
    mkdir -p "$ROOT/usr/bin"
    cp -a "$DEPS/dbus-1.16.2/usr/bin/." "$ROOT/usr/bin/"
fi
if [ -d "$DEPS/dbus-1.16.2/usr/share/dbus-1" ]; then
    mkdir -p "$ROOT/usr/share/dbus-1"
    cp -a "$DEPS/dbus-1.16.2/usr/share/dbus-1/." "$ROOT/usr/share/dbus-1/"
fi
if [ -d "$DEPS/dbus-1.16.2/etc/dbus-1" ]; then
    mkdir -p "$ROOT/etc/dbus-1"
    cp -a "$DEPS/dbus-1.16.2/etc/dbus-1/." "$ROOT/etc/dbus-1/"
fi

# --- xfce4-terminal (GTK3 terminal, Wayland) ----------------------------------
if [ -d "$DEPS/xfce4-terminal-1.2.0/bin" ]; then
    mkdir -p "$ROOT/usr/bin"
    cp -a "$DEPS/xfce4-terminal-1.2.0/bin/." "$ROOT/usr/bin/"
fi
if [ -d "$DEPS/xfce4-terminal-1.2.0/share/applications" ]; then
    mkdir -p "$ROOT/usr/share/applications"
    cp -a "$DEPS/xfce4-terminal-1.2.0/share/applications/." "$ROOT/usr/share/applications/"
fi
if [ -d "$DEPS/xfce4-terminal-1.2.0/share/icons" ]; then
    mkdir -p "$ROOT/usr/share/icons"
    cp -a "$DEPS/xfce4-terminal-1.2.0/share/icons/." "$ROOT/usr/share/icons/"
fi

# --- thunar (file manager, activates via dbus FileManager1) -------------------
if [ -d "$DEPS/thunar-4.20.9/bin" ]; then
    mkdir -p "$ROOT/usr/bin"
    cp -a "$DEPS/thunar-4.20.9/bin/." "$ROOT/usr/bin/"
fi
if [ -d "$DEPS/thunar-4.20.9/share/applications" ]; then
    mkdir -p "$ROOT/usr/share/applications"
    cp -a "$DEPS/thunar-4.20.9/share/applications/." "$ROOT/usr/share/applications/"
fi
if [ -d "$DEPS/thunar-4.20.9/share/icons" ]; then
    mkdir -p "$ROOT/usr/share/icons"
    cp -a "$DEPS/thunar-4.20.9/share/icons/." "$ROOT/usr/share/icons/"
fi
if [ -d "$DEPS/thunar-4.20.9/share/dbus-1" ]; then
    mkdir -p "$ROOT/usr/share/dbus-1"
    cp -a "$DEPS/thunar-4.20.9/share/dbus-1/." "$ROOT/usr/share/dbus-1/"
fi

# --- X11 desktop: Xorg, xkbcomp, fbdev driver module -------------------------
# The server bakes its prefix (${DEPS}/x11) into the runtime and the guest
# resolves it via the /usr/share/X11/xtree alias (same trick as libinput).
XT="$ROOT/usr/share/X11/xtree"
B_X11="/home/kanan/FreeLinX-workspace/ports/build/deps/x11"
if [ -f "$DEPS/x11/bin/Xorg" ] || [ -d "$DEPS/x11/lib/xorg/modules" ]; then
    mkdir -p "$XT/bin" "$XT/lib/xorg/modules/drivers" "$XT/var/lib/xkb"
    [ -f "$DEPS/x11/bin/Xorg" ] && cp -a "$DEPS/x11/bin/Xorg" "$XT/bin/Xorg"
    [ -f "$DEPS/x11/bin/xkbcomp" ] && cp -a "$DEPS/x11/bin/xkbcomp" "$XT/bin/xkbcomp"
    # Top-level loadable modules (fbdevhw, shadow, ...)
    if [ -d "$DEPS/x11/lib/xorg/modules" ]; then
        ( cd "$DEPS/x11/lib/xorg/modules" && for m in ./*.so; do
              [ -f "$m" ] && cp -a "$m" "$XT/lib/xorg/modules/"
          done )
    fi
    [ -d "$DEPS/x11/lib/xorg/modules/drivers" ] && \
        cp -a "$DEPS/x11/lib/xorg/modules/drivers/." "$XT/lib/xorg/modules/drivers/"
    if [ -d "$DEPS/x11/lib/xorg/modules/input" ] && [ "$(ls -A "$DEPS/x11/lib/xorg/modules/input" 2>/dev/null)" ]; then
        mkdir -p "$XT/lib/xorg/modules/input"
        cp -a "$DEPS/x11/lib/xorg/modules/input/." "$XT/lib/xorg/modules/input/"
    fi
    mkdir -p "$ROOT/home/kanan/FreeLinX-workspace/ports/build/deps"
    ln -sfn /usr/share/X11/xtree "$ROOT$B_X11"
    mkdir -p "$ROOT/var/lib/xkb"
fi

# --- openbox window manager ---------------------------------------------------
OB="$DEPS/openbox-3.6.1"
if [ -f "$OB/bin/openbox" ]; then
    mkdir -p "$XT/bin"
    cp -a "$OB/bin/." "$XT/bin/"
    [ -d "$OB/etc/xdg/openbox" ] && { mkdir -p "$ROOT/etc/xdg"; cp -a "$OB/etc/xdg/openbox" "$ROOT/etc/xdg/"; }
    # Prefer the FreeLinX template menu over the stock Openbox one.
    _fl_tmpl="$(cd "$(dirname "$0")/.." && pwd)/rootfs/etc/xdg/openbox/menu.xml"
    if [ -f "$_fl_tmpl" ]; then
        cp -a "$_fl_tmpl" "$ROOT/etc/xdg/openbox/menu.xml"
    fi
    [ -d "$OB/share/themes" ] && { mkdir -p "$XT/share/themes"; cp -a "$OB/share/themes/." "$XT/share/themes/"; }
    [ -d "$OB/share/xsessions" ] && { mkdir -p "$ROOT/usr/share/xsessions"; cp -a "$OB/share/xsessions/." "$ROOT/usr/share/xsessions/"; }
    [ -d "$OB/share/openbox" ] && { mkdir -p "$XT/share/openbox"; cp -a "$OB/share/openbox/." "$XT/share/openbox/"; }
    mkdir -p "$ROOT/home/kanan/FreeLinX-workspace/ports/build/deps"
    ln -sfn /usr/share/X11/xtree "$ROOT/home/kanan/FreeLinX-workspace/ports/build/deps/openbox-3.6.1"
fi

# --- runtime directories -----------------------------------------------------
mkdir -p "$ROOT/run" "$ROOT/dev/pts" "$ROOT/tmp" "$ROOT/var/log"
chmod 1777 "$ROOT/tmp"

freelinx_info "Graphical runtime staged."

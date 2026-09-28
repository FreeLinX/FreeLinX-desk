#!/bin/sh
# FreeLinX Desktop - install the built GUI stack into src/rootfs
#
# Copies the runtime half of $STACK_WORK/sysroot (shared libraries, Xorg and
# its modules, rebuilt userland, GTK data) and the staged Firefox into the
# rootfs template, replacing the old GCC/glibc-contaminated copies, then runs
# check-nognu.sh on the result.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
SYS="$W/sysroot"
R="${ROOTFS:-$TOP/src/rootfs}"
STRIP="$TC/bin/llvm-strip"

[ -d "$SYS/usr/lib" ] || { echo "no stack sysroot: $SYS" >&2; exit 1; }

cp_strip() { # src dst
    mkdir -p "$(dirname "$2")"
    rm -f "$2"
    cp -P "$1" "$2"
    [ -L "$2" ] || "$STRIP" --strip-unneeded "$2" 2>/dev/null || :
}

# --- musl: one loader, from the stack build --------------------------------
cp_strip "$SYS/usr/lib/libc.so" "$R/lib/ld-musl-x86_64.so.1"

# --- shared libraries --------------------------------------------------------
# Runtime objects only: *.so.N[.N...] plus the symlinks pointing at them.
( cd "$SYS/usr/lib" && find . -maxdepth 1 \( -type f -o -type l \) -name '*.so.*' ) |
while IFS= read -r f; do
    cp_strip "$SYS/usr/lib/$f" "$R/usr/lib/$f"
done
# /lib/libudev.so.1 used to be a 10-symbol stub; libinput/evdev then jumped
# through an unresolved PLT slot.  One libudev: libudev-zero in /usr/lib.
if [ -f "$SYS/usr/lib/libudev.so.1" ]; then
    rm -f "$R/lib/libudev.so.1" "$R/lib/libudev.so"
    ln -s ../usr/lib/libudev.so.1 "$R/lib/libudev.so.1"
fi
# A few libraries are loaded by plain name.
for n in libc++ libc++abi libunwind; do
    [ -e "$SYS/usr/lib/$n.so.1" ] && ln -sf "$n.so.1" "$R/usr/lib/$n.so"
done
# libgcc_s was only a name shim over libunwind for the old prebuilt Rust
# binaries; the rebuilt ones link libunwind directly.
if [ -x "$SYS/usr/bin/greetd" ]; then
    rm -f "$R/lib/libgcc_s.so.1" "$R/usr/lib/libgcc_s.so.1"
fi

# gdk-pixbuf / gio / gtk module trees and PAM modules
for d in gdk-pixbuf-2.0 gio gtk-3.0 imlib2; do
    [ -d "$SYS/usr/lib/$d" ] || continue
    rm -rf "$R/usr/lib/$d"
    cp -a "$SYS/usr/lib/$d" "$R/usr/lib/$d"
done
if [ -d "$SYS/lib/security" ]; then
    for m in "$SYS/lib/security"/*.so; do cp_strip "$m" "$R/lib/security/$(basename "$m")"; done
fi
[ -f "$SYS/usr/lib/libpam.so.0" ] && rm -f "$R/lib/libpam.so" "$R/lib/libpam.so.0" "$R/lib/libpam.so.0.85.1"

# --- Xorg --------------------------------------------------------------------
cp_strip "$SYS/usr/bin/Xorg" "$R/usr/bin/Xorg"
rm -rf "$R/usr/lib/xorg/modules"
mkdir -p "$R/usr/lib/xorg"
cp -a "$SYS/usr/lib/xorg/modules" "$R/usr/lib/xorg/modules"
find "$R/usr/lib/xorg/modules" -name '*.so' -exec "$STRIP" --strip-unneeded {} \;
[ -f "$SYS/usr/lib/xorg/protocol.txt" ] && cp -f "$SYS/usr/lib/xorg/protocol.txt" "$R/usr/lib/xorg/"
# The old private X tree duplicated the server and modules; point it at the
# single copy so existing ModulePath/PATH entries keep working.
if [ -d "$R/usr/share/X11/xtree" ]; then
    rm -rf "$R/usr/share/X11/xtree/lib/xorg/modules" "$R/usr/share/X11/xtree/bin/Xorg"
    mkdir -p "$R/usr/share/X11/xtree/lib/xorg"
    ln -s /usr/lib/xorg/modules "$R/usr/share/X11/xtree/lib/xorg/modules"
    ln -s /usr/bin/Xorg "$R/usr/share/X11/xtree/bin/Xorg"
fi

# --- rebuilt userland binaries ---------------------------------------------
for b in xkbcomp dbus-daemon dbus-send dbus-monitor dbus-uuidgen dbus-cleanup-sockets \
         dbus-run-session xpkg nnn xcalc greetd agreety tuigreet tint2; do
    [ -f "$SYS/usr/bin/$b" ] || continue
    # keep the binary where the rootfs already had it (bin/ or usr/bin/)
    dst="$R/usr/bin/$b"
    [ -e "$R/bin/$b" ] && [ ! -e "$R/usr/bin/$b" ] && dst="$R/bin/$b"
    cp_strip "$SYS/usr/bin/$b" "$dst"
done
for b in wpa_supplicant wpa_cli wpa_passphrase flxifconfig flxroute; do
    s="$SYS/sbin/$b"; [ -f "$s" ] || s="$SYS/usr/sbin/$b"
    [ -f "$s" ] && cp_strip "$s" "$R/sbin/$b"
done
[ -f "$SYS/usr/libexec/dbus-daemon-launch-helper" ] && \
    cp_strip "$SYS/usr/libexec/dbus-daemon-launch-helper" "$R/usr/libexec/dbus-daemon-launch-helper"

# ALSA tools (alsamixer replaces the old wrapper that had no mixer behind it)
for b in alsamixer amixer aplay speaker-test; do
    [ -f "$SYS/usr/bin/$b" ] && cp_strip "$SYS/usr/bin/$b" "$R/usr/bin/$b"
done
[ -f "$R/usr/bin/aplay" ] && ln -sf aplay "$R/usr/bin/arecord"
if [ -d "$SYS/usr/share/sounds/alsa" ]; then
    mkdir -p "$R/usr/share/sounds"; rm -rf "$R/usr/share/sounds/alsa"
    cp -a "$SYS/usr/share/sounds/alsa" "$R/usr/share/sounds/alsa"
fi
for b in flxinstall-gui flxnetmgr; do
    [ -f "$SYS/usr/bin/$b" ] && cp_strip "$SYS/usr/bin/$b" "$R/usr/bin/$b"
done
# toybox fills only the gaps (ps, top, free, uptime, pgrep, pidof, w); tools
# the NetBSD userland already ships keep their NetBSD versions.
if [ -f "$SYS/usr/bin/toybox" ]; then
    cp_strip "$SYS/usr/bin/toybox" "$R/usr/bin/toybox"
    for t in ps top free uptime pgrep pkill pidof w getty setsid; do
        have=""
        for d in bin sbin usr/bin usr/sbin; do
            [ -e "$R/$d/$t" ] && [ ! -L "$R/$d/$t" ] && have=1
        done
        [ -z "$have" ] && ln -sf toybox "$R/usr/bin/$t"
    done
    # console logins (getty -l): toybox login reads /etc/shadow via crypt(3)
    mkdir -p "$R/usr/libexec/toybox"
    ln -sf /usr/bin/toybox "$R/usr/libexec/toybox/login"
fi

# --- data --------------------------------------------------------------------
# fontconfig: conf.d used to link into a build machine's ports tree, so none
# of the rules (sans-serif alias, hinting, ...) ever loaded.
if [ -d "$SYS/usr/share/fontconfig/conf.avail" ]; then
    rm -rf "$R/usr/share/fontconfig/conf.avail"
    mkdir -p "$R/usr/share/fontconfig" "$R/etc/fonts/conf.d"
    cp -a "$SYS/usr/share/fontconfig/conf.avail" "$R/usr/share/fontconfig/conf.avail"
    find "$R/etc/fonts/conf.d" -type l -delete
    for c in "$SYS/etc/fonts/conf.d"/*.conf; do
        n=$(basename "$c")
        ln -s "/usr/share/fontconfig/conf.avail/$n" "$R/etc/fonts/conf.d/$n"
    done
    cp -f "$SYS/etc/fonts/fonts.conf" "$R/etc/fonts/fonts.conf"
fi
if [ -d "$SYS/usr/share/zoneinfo" ]; then
    rm -rf "$R/usr/share/zoneinfo"
    cp -a "$SYS/usr/share/zoneinfo" "$R/usr/share/zoneinfo"
fi
if [ -d "$SYS/usr/share/glib-2.0/schemas" ]; then
    mkdir -p "$R/usr/share/glib-2.0"
    rm -rf "$R/usr/share/glib-2.0/schemas"
    cp -a "$SYS/usr/share/glib-2.0/schemas" "$R/usr/share/glib-2.0/schemas"
    glib-compile-schemas "$R/usr/share/glib-2.0/schemas"
fi
for d in libinput alsa; do
    [ -d "$SYS/usr/share/$d" ] && rm -rf "$R/usr/share/$d" && cp -a "$SYS/usr/share/$d" "$R/usr/share/$d"
done
for d in terminfo X11/locale; do
    [ -d "$SYS/usr/share/$d" ] && [ ! -d "$R/usr/share/$d" ] && \
        mkdir -p "$R/usr/share/$d" && cp -a "$SYS/usr/share/$d/." "$R/usr/share/$d/"
done

# --- Firefox -----------------------------------------------------------------
FF="$W/firefox-dest/usr/lib/firefox"
if [ -d "$FF" ]; then
    rm -rf "$R/usr/lib/firefox"
    cp -a "$FF" "$R/usr/lib/firefox"
    ln -sf /usr/lib/firefox/firefox "$R/usr/bin/firefox"
    mkdir -p "$R/usr/share/applications"
    cp -f "$HERE/firefox/firefox.desktop" "$R/usr/share/applications/firefox.desktop"
    mkdir -p "$R/usr/lib/firefox/defaults/pref" "$R/usr/lib/firefox/distribution"
    cp -f "$HERE/firefox/freelinx-prefs.js" "$R/usr/lib/firefox/defaults/pref/freelinx-prefs.js"
    for s in 16 32 48 64 128; do
        i="$FF/browser/chrome/icons/default/default$s.png"
        [ -f "$i" ] || continue
        mkdir -p "$R/usr/share/icons/hicolor/${s}x${s}/apps"
        cp -f "$i" "$R/usr/share/icons/hicolor/${s}x${s}/apps/firefox.png"
    done
fi

echo "install-stack: done; checking the tree"
"$TOP/check-nognu.sh" "$R"

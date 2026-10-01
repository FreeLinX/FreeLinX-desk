#!/bin/sh
# FreeLinX Desktop - turn the built stack into xpkg packages
#
# Every stack component is installed again, on its own, into a staging tree
# (from its build directory: meson/ninja or make DESTDIR=), trimmed to what
# runs on the target (no headers, static archives, pkg-config or docs),
# stripped, checked by check-nognu.sh, and packed with xpkg-create.
# Dependencies come from the ELF files themselves: every DT_NEEDED soname is
# mapped to the package that ships it.
#
#   stack/package-stack.sh [name...]      default: every component
#
# Output: stack/work/pkgs/<name>-<version>-<rel>.xpkg
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
SYS="$W/sysroot"
OUT="$W/pkgs"
ST="$W/pkgstage"
REL="${PKGREL:-1}"
XPKG_SRC="${XPKG_SRC:-$TOP/../xpkg}"
MESON="${MESON:-$TOP/.venv/bin/meson}"
[ -x "$MESON" ] || MESON=meson
READELF="$TC/bin/llvm-readelf"
STRIP="$TC/bin/llvm-strip"

mkdir -p "$OUT" "$ST"
CREATE="$W/build/xpkg-create"
"$W/bin/flx-cc" -O2 -o "$CREATE" "$XPKG_SRC/tools/xpkg-create.c" -lz -lcrypto
create() { "$W/bin/musl-run" "$CREATE" "$@"; }

# name | source (for the version) | how | description
# how: b:<dir>        install from stack/work/build/<dir> (meson or make)
#      s:<dir>:<args> make install in the unpacked source tree with <args>
#      f:<paths>      copy these paths out of the sysroot (comma separated)
PKGS='
musl|musl|m:|musl C library (runtime)
libcxx|llvm-project|b:cxxrt|LLVM libc++, libc++abi and libunwind (runtime)
zlib|zlib|s:zlib:install|zlib compression library
libffi|libffi|b:libffi|Foreign function interface library
pcre2|pcre2|b:pcre2|Perl-compatible regular expressions
expat|expat|b:expat|XML parser library
libpng|libpng|b:libpng|PNG image library
libjpeg-turbo|libjpeg-turbo|b:libjpeg-turbo|JPEG image codec
freetype|freetype|b:freetype|Font rendering engine
fontconfig|fontconfig|b:fontconfig|Font configuration and lookup
pixman|pixman|b:pixman|Low-level pixel manipulation library
libmd|libmd|b:libmd|Message digest functions (MD5, SHA)
libXau|libXau|b:libXau|X11 authorisation library
libXdmcp|libXdmcp|b:libXdmcp|X Display Manager Control Protocol library
libxcb|libxcb|b:libxcb|X protocol C binding
libX11|libX11|b:libX11|Core X11 client library
libXext|libXext|b:libXext|X11 extensions library
libXrender|libXrender|b:libXrender|X Render extension library
libXfixes|libXfixes|b:libXfixes|X Fixes extension library
libXi|libXi|b:libXi|X Input extension library
libXrandr|libXrandr|b:libXrandr|X RandR extension library
libXcursor|libXcursor|b:libXcursor|X cursor management library
libXcomposite|libXcomposite|b:libXcomposite|X Composite extension library
libXdamage|libXdamage|b:libXdamage|X Damage extension library
libXinerama|libXinerama|b:libXinerama|Xinerama multi-head library
libXtst|libXtst|b:libXtst|X Test extension library
libICE|libICE|b:libICE|Inter-Client Exchange library
libSM|libSM|b:libSM|X Session Management library
libXt|libXt|b:libXt|X Toolkit Intrinsics
libXmu|libXmu|b:libXmu|X miscellaneous utilities library
libXft|libXft|b:libXft|FreeType fonts for X
libXpm|libXpm|b:libXpm|X pixmap library
libxkbfile|libxkbfile|b:libxkbfile|XKB file handling library
libfontenc|libfontenc|b:libfontenc|X font encoding library
libXfont2|libXfont2|b:libXfont2|X font rasterisation library
libxshmfence|libxshmfence|b:libxshmfence|Shared memory fences for X
libpciaccess|libpciaccess|b:libpciaccess|PCI device access library
libdrm|libdrm|b:libdrm|Direct Rendering Manager library (Intel, AMD, NVIDIA)
libxcvt|libxcvt|b:libxcvt|VESA CVT mode line calculator
mtdev|mtdev|b:mtdev|Multitouch protocol translation library
libevdev|libevdev|b:libevdev|Linux input device library
libudev-zero|libudev-zero|s:libudev-zero:PREFIX=/usr install|libudev replacement without udev
xorg-server|xorg-server|b:xorg-server|X.Org display server with glamor, DRI3 and GLX
xf86-video-fbdev|xf86-video-fbdev|b:xf86-video-fbdev|Xorg framebuffer video driver
xf86-input-evdev|xf86-input-evdev|f:usr/lib/xorg/modules/input/evdev_drv.so|Xorg evdev input driver
xkbcomp|xkbcomp|b:xkbcomp|XKB keymap compiler
libinput|libinput|b:libinput|Input device handling library
xf86-input-libinput|xf86-input-libinput|b:xf86-input-libinput|Xorg libinput input driver
glib|glib|b:glib|GLib, GObject and GIO libraries
fribidi|fribidi|b:fribidi|Unicode bidirectional algorithm
harfbuzz|harfbuzz|b:harfbuzz|Text shaping engine
cairo|cairo|b:cairo|2D graphics library
pango|pango|b:pango|Text layout and rendering
gdk-pixbuf|gdk-pixbuf|b:gdk-pixbuf|Image loading library
libxml2|libxml2|b:libxml2|XML toolkit
dbus|dbus|b:dbus|D-Bus message bus
at-spi2-core|at-spi2-core|b:at-spi2-core|Accessibility toolkit (ATK, AT-SPI)
libepoxy|libepoxy|b:libepoxy|OpenGL function pointer management
gtk3|gtk|b:gtk|GTK 3 graphical toolkit
alsa-lib|alsa-lib|b:alsa-lib|ALSA sound library
tzdata|tzdata|f:usr/share/zoneinfo|IANA time zone database
toybox|toybox|f:usr/bin/toybox,usr/bin/ps,usr/bin/top,usr/bin/free,usr/bin/uptime,usr/bin/pgrep,usr/bin/pkill,usr/bin/pidof,usr/bin/w,usr/bin/getty,usr/bin/login,usr/bin/setsid|Process and system tools (ps, top, free, pgrep, getty, login)
openssl|openssl|s:openssl:install_sw install_ssldirs|TLS/SSL and crypto library
sqlite|sqlite|b:sqlite|SQLite database engine
libnl|libnl|b:libnl|Netlink library
wpa_supplicant|wpa_supplicant|f:sbin/wpa_supplicant,sbin/wpa_cli,sbin/wpa_passphrase|WiFi client (WPA2/WPA3, 802.1X)
ncurses|ncurses|b:ncurses|Terminal handling library
nnn|nnn|s:nnn:PREFIX=/usr install|Fast terminal file manager
libXaw|libXaw|b:libXaw|X Athena widgets
xcalc|xcalc|b:xcalc|Scientific calculator for X
imlib2|imlib2|b:imlib2|Image loading and rendering library
tint2|tint2|b:tint2|Desktop panel and taskbar
alsa-utils|alsa-utils|b:alsa-utils|ALSA tools: alsamixer, amixer, aplay
libXxf86vm|libXxf86vm|b:libXxf86vm|XFree86 video mode extension library
mesa|mesa|b:mesa|OpenGL/EGL drivers: Intel, NVIDIA (nouveau), older AMD, VMs, software
ffmpeg-libs|ffmpeg|b:ffmpeg|FFmpeg codec libraries (LGPL: H.264, AAC, VP9, AV1 decoding)
libedit|libedit|b:libedit|Line editing library (BSD)
bluez|bluez|b:bluez|Bluetooth stack: bluetoothd, bluetoothctl
hostapd|hostapd|f:sbin/hostapd,sbin/hostapd_cli|WiFi access point daemon
flxnet|flxnet|f:sbin/flxifconfig,sbin/flxroute|FreeLinX netlink ifconfig and route
flx-apps|flxapps|f:usr/bin/flxinstall-gui,usr/bin/flxnetmgr,usr/bin/flxpkg|FreeLinX installer, network manager and package manager (GUI)
xpkg|xpkg|f:usr/bin/xpkg|FreeLinX package manager
firefox|firefox|x:|FreeLinX Web: web browser based on Firefox ESR|ffmpeg-libs
xorg|xorg-server|e:|X Window System: server, input/video drivers, keymap compiler, OpenGL|xorg-server,xf86-input-libinput,xf86-input-evdev,xf86-video-fbdev,xkbcomp,mesa
'

# --- versions ------------------------------------------------------------------
# Package release: bump a package here when its contents change without a
# new upstream version, so installed systems see an upgrade.
pkg_rel() {
    case "$1" in
        xorg-server) echo 2 ;;   # 1.0.1: udev hotplug, DRI path inside the target
        gtk3) echo 2 ;;          # 1.0.1: X11 compose/locale path inside the target
        *) echo "$REL" ;;
    esac
}

src_version() { # source name -> version string
    case "$1" in
        flxnet|flxapps) date -u +%Y.%m.%d ;;   # FreeLinX's own, dated
        firefox) sed -n 's/^Version=//p' "$W/firefox-dest/usr/lib/firefox/application.ini" | head -1 ;;
        xpkg) sed -n 's/^#define XPKG_VERSION *"\(.*\)"/\1/p' "$XPKG_SRC/include/xpkg.h" ;;
        *)
            f=$(awk -v n="$1" '$1 == n { print $2 }' "$HERE/sources.txt" | sed 's|.*/||')
            v=$(printf '%s\n' "$f" | sed -E 's/\.(tar\.(gz|xz|bz2)|tgz|zip)$//')
            v=${v#"$1"-}; v=${v#"$1"}
            case "$1" in
                freetype) v=$(printf '%s' "$v" | sed 's/^VER-//; s/-/./g') ;;
                sqlite) v=$(printf '%s' "$v" | sed -E 's/^-?autoconf-//; s/^([0-9])([0-9]{2})([0-9]{2})[0-9]{2}$/\1.\2.\3/; s/\.0([0-9])/.\1/g') ;;
                tzdata) v=${v#tzdata} ;;
                llvm-project) v=${v%.src} ;;
                libedit) v=$(printf '%s' "$v" | sed -E 's/^([0-9]{8})-(.*)$/\2.\1/') ;;
            esac
            v=${v#v}; v=${v#-}
            printf '%s\n' "$v" ;;
    esac
}

# --- staging ----------------------------------------------------------------------
stage_build() { # dir dest
    b="$W/build/$1"
    [ -d "$b" ] || { echo "  no build dir $b" >&2; return 1; }
    if [ -f "$b/build.ninja" ] && [ -f "$b/meson-private/coredata.dat" ]; then
        DESTDIR="$2" "$MESON" install -C "$b" --no-rebuild --quiet >/dev/null
    elif [ -f "$b/build.ninja" ]; then
        DESTDIR="$2" ninja -C "$b" install >/dev/null
    else
        make -C "$b" DESTDIR="$2" install >/dev/null
    fi
}

stage_src() { # name[/subdir] args dest
    top=$(find "$W/src/${1%%/*}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    case "$1" in */*) s="$top/${1#*/}" ;; *) s="$top" ;; esac
    [ -n "$top" ] && [ -d "$s" ] || { echo "  no source dir for $1" >&2; return 1; }
    # shellcheck disable=SC2086
    (cd "$s" && make DESTDIR="$3" $2 >/dev/null)
}

stage_files() { # comma-list dest
    old_ifs=$IFS; IFS=,
    for p in $1; do
        [ -e "$SYS/$p" ] || [ -L "$SYS/$p" ] || { echo "  missing $SYS/$p" >&2; IFS=$old_ifs; return 1; }
        mkdir -p "$2/$(dirname "$p")"
        cp -a "$SYS/$p" "$2/$p"
    done
    IFS=$old_ifs
}

trim() { # dest: keep what the target runs
    d="$1"
    rm -rf "$d/usr/include" "$d/usr/lib/pkgconfig" "$d/usr/share/pkgconfig" \
        "$d/usr/share/aclocal" "$d/usr/lib/cmake" "$d/usr/share/gtk-doc" \
        "$d/usr/share/doc" "$d/usr/share/info" "$d/usr/share/gettext" \
        "$d/usr/share/gdb" "$d/usr/lib/python"* "$d/usr/share/xcb" \
        "$d/usr/share/installed-tests" "$d/usr/libexec/installed-tests" \
        "$d/usr/share/bash-completion" "$d/usr/share/zsh" "$d/usr/share/fish"
    find "$d" \( -name '*.a' -o -name '*.la' \) -type f -delete 2>/dev/null || :
    # GTK Inspector's property translations and the emoji picker data: large
    # and unused on this desktop
    find "$d/usr/share/locale" -name '*-properties.mo' -type f -delete 2>/dev/null || :
    rm -rf "$d/usr/share/gtk-3.0/emoji"
    # build-host wrappers must never ship, nor scripts whose interpreter is a
    # build-host path (glib's codegen tools are Python run at build time)
    rm -rf "$d/usr/libexec/flx-target" "$d/usr/share/glib-2.0/codegen"
    find "$d" -type f | while IFS= read -r f; do
        head -c 2 "$f" 2>/dev/null | grep -q '#!' || continue
        if head -1 "$f" | grep -q "^#! *$HOME"; then rm -f "$f"; fi
    done
    find "$d" -path '*/share/man/*' -type f -exec sed -i "s|$SYS||g" {} + 2>/dev/null || :
    # Firefox ships exactly as build-firefox.sh staged it (tested that way)
    find "$d" -path "$d/usr/lib/firefox" -prune -o -type f -print | while IFS= read -r f; do
        head -c 4 "$f" 2>/dev/null | grep -q 'ELF' && "$STRIP" --strip-unneeded "$f" 2>/dev/null || :
    done
    # stripping rewrote hardlinked files (Mesa's *_dri.so) as separate
    # copies: link identical large ELF files back together
    find "$d" -path "$d/etc" -prune -o -type f -size +1M -print | while IFS= read -r f; do
        head -c 4 "$f" 2>/dev/null | grep -q ELF || continue
        printf '%s %s\n' "$(sha256sum < "$f" | cut -c1-64)" "$f"
    done | sort | awk '$1 == prev { print first "\t" $2; next } { prev = $1; first = $2 }' |
    while IFS='	' read -r a b; do ln -f "$a" "$b"; done
    find "$d" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || :
}

scripts_for() { # name -> post-install script path (or empty)
    sc="$ST/.scripts/$1.post-install"
    mkdir -p "$ST/.scripts"
    case "$1" in
        glib) printf '[ -x /usr/bin/glib-compile-schemas ] && glib-compile-schemas /usr/share/glib-2.0/schemas || :\n' > "$sc" ;;
        gdk-pixbuf) printf 'gdk-pixbuf-query-loaders --update-cache 2>/dev/null || :\n' > "$sc" ;;
        gtk3) printf 'gtk-query-immodules-3.0 --update-cache 2>/dev/null || :\n[ -x /usr/bin/gtk-update-icon-cache ] && for d in /usr/share/icons/*/; do gtk-update-icon-cache -q -t "$d" 2>/dev/null || :; done\n' > "$sc" ;;
        fontconfig) printf 'fc-cache -s >/dev/null 2>&1 || :\n' > "$sc" ;;
        xorg-server) cat > "$sc" <<'XEOF'
chmod 4711 /usr/bin/Xorg
# 1.0.0 configs listed fixed /dev/fl-* input devices; with udev hotplug they
# would add every keyboard and mouse a second time: drop them.
for f in /etc/X11/xorg.conf /etc/X11/xorg-kms.conf /etc/X11/xorg-modesetting.conf; do
    [ -f "$f" ] && grep -q '/dev/fl-' "$f" || continue
    awk '/^Section "InputDevice"/ { skip = 1 }
         skip && /^EndSection/ { skip = 0; next }
         !skip && !/^[ \t]*InputDevice "/' "$f" > "$f.xpkg-new" && mv "$f.xpkg-new" "$f"
done
# with GLX working, tint2 draws panels that use a background as a black bar
t=/etc/xdg/tint2/tint2rc
if [ -f "$t" ] && grep -q '_background_id = ' "$t"; then
    sed '/^[a-z_]*_background_id = /d' "$t" > "$t.xpkg-new" && mv "$t.xpkg-new" "$t"
fi
XEOF
            ;;
        firefox) cat > "$sc" <<'FFEOF'
# the musl loader finds Firefox's private libraries through its search path
p=/etc/ld-musl-x86_64.path
[ -f "$p" ] || printf '/lib\n/usr/local/lib\n/usr/lib\n' > "$p"
grep -qx /usr/lib/firefox "$p" || echo /usr/lib/firefox >> "$p"
FFEOF
            ;;
        *) rm -f "$sc"; return 0 ;;
    esac
    echo "$sc"
}

# --- dependencies from the ELF files -------------------------------------------------
soname_map="$ST/.sonames"
needed_of() { # stage dir -> NEEDED sonames
    find "$1" -type f | while IFS= read -r f; do
        head -c 4 "$f" 2>/dev/null | grep -q ELF || continue
        "$READELF" -d "$f" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\].*/\1/p'
    done | sort -u
}
sonames_of() { # stage dir -> sonames it provides
    find "$1" \( -type f -o -type l \) -name '*.so*' | while IFS= read -r f; do
        [ -f "$f" ] || continue
        s=$("$READELF" -d "$f" 2>/dev/null | sed -n 's/.*(SONAME).*\[\(.*\)\].*/\1/p')
        [ -n "$s" ] && echo "$s"
        basename "$f"
    done | sort -u
}

want() { # name -> selected?
    [ $# -eq 0 ] && return 0
    n="$1"; shift
    for x in $SELECTED; do [ "$x" = "$n" ] && return 0; done
    return 1
}

SELECTED="$*"
echo "$PKGS" | while IFS='|' read -r name src how desc; do
    [ -n "$name" ] || continue
    if [ -n "$SELECTED" ]; then
        case " $SELECTED " in *" $name "*) ;; *) continue ;; esac
    fi
    d="$ST/$name"
    rm -rf "$d"; mkdir -p "$d"
    printf '%-22s' "$name"
    rc=0
    case "$how" in
        b:*) stage_build "${how#b:}" "$d" || rc=1 ;;
        s:*) rest=${how#s:}; stage_src "${rest%%:*}" "${rest#*:}" "$d" || rc=1 ;;
        f:*) stage_files "${how#f:}" "$d" || rc=1 ;;
        x:)  # Firefox: staged by build-firefox.sh, plus FreeLinX prefs/menu entry
             [ -d "$W/firefox-dest/usr/lib/firefox" ] || { rc=1; true; }
             if [ $rc -eq 0 ]; then
                 mkdir -p "$d/usr/lib" "$d/usr/bin" "$d/usr/share/applications"
                 cp -a "$W/firefox-dest/usr/lib/firefox" "$d/usr/lib/firefox"
                 ln -s /usr/lib/firefox/firefox "$d/usr/bin/firefox"
                 cp "$HERE/firefox/firefox.desktop" "$d/usr/share/applications/firefox.desktop"
                 mkdir -p "$d/usr/lib/firefox/defaults/pref"
                 cp "$HERE/firefox/freelinx-prefs.js" "$d/usr/lib/firefox/defaults/pref/freelinx-prefs.js"
                 for sz in 16 32 48 64 128; do
                     i="$d/usr/lib/firefox/browser/chrome/icons/default/default$sz.png"
                     [ -f "$i" ] || continue
                     mkdir -p "$d/usr/share/icons/hicolor/${sz}x${sz}/apps"
                     cp "$i" "$d/usr/share/icons/hicolor/${sz}x${sz}/apps/firefox.png"
                 done
             fi ;;
        e:)  : ;;   # meta package: dependencies only
        m:)  # the loader is the real file (replaced by one atomic rename)
             mkdir -p "$d/lib" "$d/usr/lib"
             cp -L "$SYS/usr/lib/libc.so" "$d/lib/ld-musl-x86_64.so.1"
             ln -s ../../lib/ld-musl-x86_64.so.1 "$d/usr/lib/libc.so" ;;
    esac
    if [ $rc -ne 0 ]; then echo "STAGING FAILED"; rm -rf "$d"; continue; fi
    # Xorg's input defaults (libinput, tapping) travel with the server
    if [ "$name" = xorg-server ]; then
        mkdir -p "$d/etc/X11/xorg.conf.d"
        cp "$TOP/src/rootfs/etc/X11/xorg.conf.d/50-flx-input.conf" "$d/etc/X11/xorg.conf.d/"
    fi
    # ncurses' programs (clear, tput, tic, ...) are packaged on their own
    [ "$name" = ncurses ] && rm -rf "$d/usr/bin"
    trim "$d"
    echo "$(find "$d" -type f -o -type l | wc -l) files"
done

# soname -> package, over every staged package
: > "$soname_map"
for d in "$ST"/*/; do
    n=$(basename "$d")
    sonames_of "$d" | sed "s|^|$n |" >> "$soname_map"
done

echo "$PKGS" | while IFS='|' read -r name src how desc extra; do
    [ -n "$name" ] || continue
    if [ -n "$SELECTED" ]; then
        case " $SELECTED " in *" $name "*) ;; *) continue ;; esac
    fi
    d="$ST/$name"
    [ -d "$d" ] || continue
    if ! "$TOP/check-nognu.sh" "$d" >"$ST/.nognu.log" 2>&1; then
        echo "GNU contamination in $name - not packaged:" >&2
        tail -5 "$ST/.nognu.log" >&2
        continue
    fi
    deps=$(needed_of "$d" | while IFS= read -r so; do
        awk -v s="$so" '$2 == s { print $1; exit }' "$soname_map"
    done; for x in $(echo "${extra:-}" | tr ',' ' '); do echo "$x"; done)
    deps=$(echo "$deps" | grep -v -x "$name" | grep . | sort -u | tr '\n' ',' | sed 's/,$//')
    ver="$(src_version "$src")-$(pkg_rel "$name")"
    sc=$(scripts_for "$name")
    rm -f "$OUT/$name"-[0-9]*.xpkg
    set -- --name "$name" --version "$ver" --description "$desc" --stage "$d" \
        --output "$OUT/$name-$ver.xpkg"
    [ -n "$deps" ] && set -- "$@" --depends "$deps"
    [ -n "$sc" ] && set -- "$@" --post-install "$sc"
    create create "$@" >/dev/null
    printf '%-22s %-24s %s\n' "$name" "$ver" "${deps:--}"
done
echo "package-stack: $(ls "$OUT"/*.xpkg | wc -l) packages in $OUT"

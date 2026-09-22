#!/bin/sh
# FreeLinX/ports package.sh
#
# Packages the FreeLinX desktop tools (built no-GNU, musl+clang+lld) into
# .xpkg archives and generates the repo index.json.
#
# Tools packaged here (Deliberately explicit -- this is the desktop stack):
#   dwm  dmenu  slstatus  nsxiv  xclip  xinit  xorg-server
#
# Usage:
#   ./scripts/package.sh [name ...]     package only the named tools
#   ./scripts/package.sh all            package all desktop tools (default)
#
# Output: ports/packages/*.xpkg  +  ports/packages/index.json

set -eu
. "$(dirname "$0")/common.sh"

flx_load_config

PKG_DIR="$FREELINX_ROOT/packages"
STAGE_DIR="$FREELINX_ROOT/staging"
ROOTFS_DIR="$FREELINX_ROOT/../src/rootfs"
XPKG_CREATE="$FREELINX_ROOT/../xpkg/tools/xpkg-create"
WORK_STAGE="$FREELINX_BUILD_DIR/xpkg"

[ -x "$XPKG_CREATE" ] || flx_die "xpkg-create not found: $XPKG_CREATE (build it in xpkg/tools first)"
[ -d "$ROOTFS_DIR" ] || flx_die "rootfs not found: $ROOTFS_DIR"

mkdir -p "$PKG_DIR" "$WORK_STAGE"

# name:version:description
TOOLS="openbox:3.6.1:default window manager (keybindings rc.xml: W-p/W-d/A-F2 -> dmenu_run)
dwm:6.5:dynamic window manager (suckless, fallback desktop shell)
slstatus:1.0:status monitor for the dwm bar (suckless)
xclip:0.13:X11 clipboard utility
nsxiv:32:simple X image viewer (sxiv successor, non-GNU)
dmenu:5.3:dynamic X11 menu (suckless; ships stest + dmenu_path fix)
xinit:1.4.2:X11 initialization script
xorg-server:21.1.24:Xorg X server (fbdev, musl, non-GNU)
picom:11.2:X compositor (screen-tearing fix, shadows; NO animations)
dunst:1.11.0:lightweight X11 notification daemon
alsa-utils:1.2.13:ALSA sound utilities (alsamixer, aplay, amixer)
pcmanfm:1.3.2:PCMan File Manager (GTK3, lightweight, no GNOME)
geany:2.0:fast GTK3 code/text editor (no GNU NLS)
feh:3.13.1:lightweight image viewer and wallpaper setter
slim:1.4.0:simple graphical login display manager (SLiM)
linux-pam:1.7.0:pluggable authentication modules library (PAM)
wpa_supplicant:2.11:WiFi supplicant for nl80211/WPA2/WPA3
dhcpcd:10.5.2:DHCP client daemon for IP configuration
lxappearance:0.6.3:LXAppearance GTK3 theme and icon switcher
xarchiver:0.5.4.23:GTK3 graphical archive manager (7z, zip, tar.gz)"

# copy helper: cp_one <stage> <destpath> <srcpath>
cp_one() {
    _stage=$1
    _dest=$2
    _src=$3
    [ -f "$_src" ] || { printf '[package][skip] %s missing (needed at %s)\n' "$_src" "$_dest"; return 1; }
    mkdir -p "$_stage/$(dirname "$_dest")"
    cp -a "$_src" "$_stage/$_dest"
}

package_one() {
    _name=$1
    _ver=$2
    _desc=$3
    _stage="$WORK_STAGE/$_name"
    rm -rf "$_stage"
    mkdir -p "$_stage"

    case "$_name" in
        dwm|slstatus|xclip)
            cp_one "$_stage" "bin/$_name" "$STAGE_DIR/bin/$_name"
            ;;
        nsxiv)
            cp_one "$_stage" "bin/nsxiv" "$STAGE_DIR/bin/nsxiv"
            ;;
        dmenu)
            cp_one "$_stage" "bin/dmenu"       "$ROOTFS_DIR/bin/dmenu"
            cp_one "$_stage" "bin/dmenu_path"  "$ROOTFS_DIR/bin/dmenu_path"
            cp_one "$_stage" "bin/dmenu_run"   "$ROOTFS_DIR/bin/dmenu_run"
            cp_one "$_stage" "bin/stest"       "$ROOTFS_DIR/bin/stest"
            ;;
        openbox)
            cp_one "$_stage" "bin/openbox"       "$ROOTFS_DIR/usr/share/X11/xtree/bin/openbox"
            cp_one "$_stage" "usr/bin/openbox-session" "$ROOTFS_DIR/usr/bin/openbox-session"
            cp_one "$_stage" "usr/lib/openbox/openbox-autostart" "$ROOTFS_DIR/usr/lib/openbox/openbox-autostart"
            cp_one "$_stage" "etc/xdg/openbox/rc.xml" "$ROOTFS_DIR/etc/xdg/openbox/rc.xml"
            ;;
        xinit)
            cp_one "$_stage" "bin/xinit"  "$STAGE_DIR/bin/xinit"
            cp_one "$_stage" "bin/startx" "$ROOTFS_DIR/bin/startx"
            cp_one "$_stage" "etc/X11/xinit/xinitrc" "$ROOTFS_DIR/etc/X11/xinit/xinitrc"
            ;;
        xorg-server)
            cp_one "$_stage" "usr/bin/Xorg" "$ROOTFS_DIR/usr/bin/Xorg"
            if [ -d "$ROOTFS_DIR/usr/lib/xorg" ]; then
                mkdir -p "$_stage/usr/lib"
                cp -a "$ROOTFS_DIR/usr/lib/xorg" "$_stage/usr/lib/"
            fi
            cp_one "$_stage" "etc/X11/xorg.conf" "$ROOTFS_DIR/etc/X11/xorg.conf"
            ;;
        picom)
            cp_one "$_stage" "bin/picom" "$STAGE_DIR/bin/picom" 2>/dev/null || cp_one "$_stage" "usr/bin/picom" "$ROOTFS_DIR/usr/bin/picom" 2>/dev/null || true
            cp_one "$_stage" "etc/xdg/picom/picom.conf" "$ROOTFS_DIR/etc/xdg/picom/picom.conf" 2>/dev/null || true
            ;;
        dunst)
            cp_one "$_stage" "bin/dunst" "$STAGE_DIR/bin/dunst" 2>/dev/null || cp_one "$_stage" "usr/bin/dunst" "$ROOTFS_DIR/usr/bin/dunst" 2>/dev/null || true
            cp_one "$_stage" "etc/xdg/dunst/dunstrc" "$ROOTFS_DIR/etc/xdg/dunst/dunstrc" 2>/dev/null || true
            ;;
        alsa-utils)
            for _b in alsamixer amixer aplay arecord alsactl speaker-test; do
                cp_one "$_stage" "bin/$_b" "$STAGE_DIR/bin/$_b" 2>/dev/null || cp_one "$_stage" "bin/$_b" "$ROOTFS_DIR/bin/$_b" 2>/dev/null || true
            done
            ;;
        pcmanfm)
            cp_one "$_stage" "bin/pcmanfm" "$STAGE_DIR/bin/pcmanfm" 2>/dev/null || cp_one "$_stage" "usr/bin/pcmanfm" "$ROOTFS_DIR/usr/bin/pcmanfm" 2>/dev/null || true
            ;;
        geany)
            cp_one "$_stage" "bin/geany" "$STAGE_DIR/bin/geany" 2>/dev/null || cp_one "$_stage" "usr/bin/geany" "$ROOTFS_DIR/usr/bin/geany" 2>/dev/null || true
            ;;
        feh)
            cp_one "$_stage" "bin/feh" "$STAGE_DIR/bin/feh" 2>/dev/null || cp_one "$_stage" "usr/bin/feh" "$ROOTFS_DIR/usr/bin/feh" 2>/dev/null || true
            ;;
        slim)
            cp_one "$_stage" "bin/slim" "$STAGE_DIR/bin/slim" 2>/dev/null || cp_one "$_stage" "usr/bin/slim" "$ROOTFS_DIR/usr/bin/slim" 2>/dev/null || true
            ;;
        linux-pam)
            if [ -d "$STAGE_DIR/lib" ]; then
                mkdir -p "$_stage/lib"
                cp -a "$STAGE_DIR/lib"/libpam* "$_stage/lib/" 2>/dev/null || true
            fi
            ;;
        wpa_supplicant)
            cp_one "$_stage" "sbin/wpa_supplicant" "$ROOTFS_DIR/sbin/wpa_supplicant" 2>/dev/null || cp_one "$_stage" "sbin/wpa_supplicant" "$STAGE_DIR/sbin/wpa_supplicant" 2>/dev/null || true
            cp_one "$_stage" "sbin/wpa_cli" "$ROOTFS_DIR/sbin/wpa_cli" 2>/dev/null || true
            cp_one "$_stage" "sbin/wpa_passphrase" "$ROOTFS_DIR/sbin/wpa_passphrase" 2>/dev/null || true
            ;;
        dhcpcd)
            cp_one "$_stage" "sbin/dhcpcd" "$ROOTFS_DIR/sbin/dhcpcd" 2>/dev/null || cp_one "$_stage" "sbin/dhcpcd" "$STAGE_DIR/sbin/dhcpcd" 2>/dev/null || true
            ;;
        lxappearance)
            cp_one "$_stage" "bin/lxappearance" "$STAGE_DIR/bin/lxappearance" 2>/dev/null || cp_one "$_stage" "usr/bin/lxappearance" "$ROOTFS_DIR/usr/bin/lxappearance" 2>/dev/null || true
            ;;
        xarchiver)
            cp_one "$_stage" "bin/xarchiver" "$STAGE_DIR/bin/xarchiver" 2>/dev/null || cp_one "$_stage" "usr/bin/xarchiver" "$ROOTFS_DIR/usr/bin/xarchiver" 2>/dev/null || true
            ;;
    esac

    _out="$PKG_DIR/${_name}-${_ver}.xpkg"
    printf '[FreeLinX/ports] packaging %s-%s\n' "$_name" "$_ver"
    "$XPKG_CREATE" create \
        --name "$_name" \
        --version "$_ver" \
        --description "$_desc" \
        --arch "$FREELINX_ARCH" \
        --stage "$_stage" \
        --output "$_out"
}

# filtered subset or all
if [ $# -gt 0 ] && [ "$1" != "all" ]; then
    _spec=""
    for _arg in "$@"; do
        _m=$(printf '%s\n' "$TOOLS" | grep "^$_arg:" || true)
        [ -z "$_m" ] && flx_die "unknown desktop tool: $_arg"
        _spec="$_spec
$_m"
    done
    TOOLS=$_spec
fi

_old_ifs=$IFS
IFS='
'
for _line in $TOOLS; do
    _name=${_line%%:*}
    _ver=$(printf '%s\n' "$_line" | cut -d: -f2)
    _desc=$(printf '%s\n' "$_line" | cut -d: -f3)
    [ -z "$_name" ] && continue
    package_one "$_name" "$_ver" "$_desc"
done
IFS=$_old_ifs

printf '[FreeLinX/ports] updating repo index: %s/index.json\n' "$PKG_DIR"
"$XPKG_CREATE" index --dir "$PKG_DIR" --output "$PKG_DIR/index.json"
printf '[FreeLinX/ports] done. %d desktop tool packages indexed.\n' \
    "$(grep -c '"file":' "$PKG_DIR/index.json" 2>/dev/null || printf 0)"
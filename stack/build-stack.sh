#!/bin/sh
# FreeLinX Desktop - GUI stack builder (musl + clang/LLD, no GNU in the output)
#
# Builds the shared-library desktop stack the release image runs on:
#
#   sysroot   musl 1.2.5 (clang), Linux 6.6 UAPI headers, libc++/libc++abi/
#             libunwind (LLVM runtimes, built against musl)
#   base      zlib libffi pcre2 expat libpng libjpeg-turbo freetype fontconfig
#             pixman libmd
#   x11       xorgproto xcb-proto libXau ... libXft libXfont2 libdrm
#   xorg      Xorg server (fbdev, no GLX), xf86-video-fbdev, xf86-input-evdev,
#             xkbcomp
#   gtk       glib fribidi harfbuzz cairo pango gdk-pixbuf atk libepoxy gtk3
#   audio     alsa-lib
#
# Everything is cross compiled from the build host with the FreeLinX LLVM
# toolchain into $STACK_WORK/sysroot (prefix /usr).  GNU tools may run on the
# *host* during the build (make, bison, m4, pkgconf); nothing GNU is linked into
# the result - check-nognu.sh verifies that when the stack is installed.
#
# Usage:
#   stack/build-stack.sh               build every step not yet stamped
#   stack/build-stack.sh gtk3 glib     (re)build only the named steps
#   STACK_WORK=/big/disk stack/build-stack.sh
#
# Sources are listed in stack/sources.txt (name url sha256).  A "-" hash is
# trust-on-first-use: the hash of the first download is written to
# stack/sources.lock and enforced from then on.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
SYS="$W/sysroot"
DIST="${STACK_DIST:-$TOP/ports/dist}"
JOBS="${JOBS:-$(nproc)}"
TARGET=x86_64-linux-musl
BUILD_TRIPLE=x86_64-pc-linux-gnu

mkdir -p "$W/src" "$W/build" "$W/stamps" "$W/logs" "$W/bin" "$SYS" "$DIST"

# --- toolchain wrappers ------------------------------------------------------
# Linker-only flags are added only when the driver links, so compile checks
# run with -Werror=unused-command-line-argument (meson) stay clean.
mkwrap() { # name driver compile-flags link-flags
    cat > "$W/bin/$1" <<EOF
#!/bin/sh
link=1
for a in "\$@"; do
    case "\$a" in -c|-S|-E|-M|-MM) link=0 ;; esac
done
if [ "\$link" = 1 ]; then
    exec "$TC/bin/$2" --target=$TARGET --sysroot="$SYS" $3 -fuse-ld=lld -Wl,--undefined-version -rtlib=compiler-rt $4 "\$@"
fi
exec "$TC/bin/$2" --target=$TARGET --sysroot="$SYS" $3 "\$@"
EOF
}
mkwrap flx-cc clang "" "-unwindlib=none"
mkwrap flx-c++ clang++ "-stdlib=libc++" "-unwindlib=libunwind"
cat > "$W/bin/pkg-config" <<EOF
#!/bin/sh
export PKG_CONFIG_SYSROOT_DIR="$SYS"
export PKG_CONFIG_LIBDIR="$SYS/usr/lib/pkgconfig:$SYS/usr/share/pkgconfig"
unset PKG_CONFIG_PATH
exec pkgconf "\$@"
EOF
# Run a target binary on the build host through the sysroot's musl loader.
cat > "$W/bin/musl-run" <<EOF
#!/bin/sh
exec "$SYS/usr/lib/libc.so" --library-path "$SYS/usr/lib" "\$@"
EOF
# The target llvm-config (radeonsi/llvmpipe) answers for the sysroot when run
# from it.
cat > "$W/bin/llvm-config" <<LLEOF
#!/bin/sh
exec "$W/bin/musl-run" "$SYS/usr/bin/llvm-config" "\$@"
LLEOF
chmod +x "$W/bin/flx-cc" "$W/bin/flx-c++" "$W/bin/pkg-config" "$W/bin/musl-run" "$W/bin/llvm-config"

MESON="${MESON:-$TOP/.venv/bin/meson}"
[ -x "$MESON" ] || MESON=meson
cat > "$W/cross.ini" <<EOF
[binaries]
c = '$W/bin/flx-cc'
cpp = '$W/bin/flx-c++'
ar = '$TC/bin/llvm-ar'
nm = '$TC/bin/llvm-nm'
strip = '$TC/bin/llvm-strip'
ranlib = '$TC/bin/llvm-ranlib'
objcopy = '$TC/bin/llvm-objcopy'
pkg-config = '$W/bin/pkg-config'
exe_wrapper = '$W/bin/musl-run'
llvm-config = '$W/bin/llvm-config'

[built-in options]
c_args = ['-O2']
cpp_args = ['-O2']

[properties]
needs_exe_wrapper = true
sys_root = '$SYS'
pkg_config_libdir = '$SYS/usr/lib/pkgconfig:$SYS/usr/share/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

cat > "$W/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_SYSROOT "$SYS")
set(CMAKE_C_COMPILER "$W/bin/flx-cc")
set(CMAKE_CXX_COMPILER "$W/bin/flx-c++")
set(CMAKE_AR "$TC/bin/llvm-ar")
set(CMAKE_RANLIB "$TC/bin/llvm-ranlib")
set(CMAKE_NM "$TC/bin/llvm-nm")
set(CMAKE_STRIP "$TC/bin/llvm-strip")
set(CMAKE_CROSSCOMPILING_EMULATOR "$W/bin/musl-run")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

export PATH="$W/bin:$PATH"
export PKG_CONFIG="$W/bin/pkg-config"
export CC="$W/bin/flx-cc" CXX="$W/bin/flx-c++"
export AR="$TC/bin/llvm-ar" RANLIB="$TC/bin/llvm-ranlib" NM="$TC/bin/llvm-nm"
export STRIP="$TC/bin/llvm-strip" OBJCOPY="$TC/bin/llvm-objcopy" OBJDUMP="$TC/bin/llvm-objdump"
export LD="$TC/bin/ld.lld"
export CFLAGS="-O2" CXXFLAGS="-O2"
export ACLOCAL_PATH="$SYS/usr/share/aclocal"
export CC_FOR_BUILD="${CC_FOR_BUILD:-cc}"

# --- sources -----------------------------------------------------------------
LOCK="$HERE/sources.lock"
touch "$LOCK"

src_line() { awk -v n="$1" '$1 == n { print; exit }' "$HERE/sources.txt"; }

fetch() { # name -> prints archive path
    line=$(src_line "$1")
    [ -n "$line" ] || { echo "build-stack: no source entry for $1" >&2; exit 1; }
    url=$(echo "$line" | awk '{print $2}')
    want=$(echo "$line" | awk '{print $3}')
    file="$DIST/$(echo "$line" | awk '{print ($4 != "" ? $4 : "")}')"
    [ "$file" = "$DIST/" ] && file="$DIST/$(basename "$url")"
    if [ ! -f "$file" ]; then
        echo "  fetch $url" >&2
        curl -fL --retry 3 -o "$file.part" "$url" >&2 && mv "$file.part" "$file"
    fi
    got=$(sha256sum "$file" | awk '{print $1}')
    if [ "$want" = "-" ]; then
        want=$(awk -v n="$1" '$1 == n { print $2 }' "$LOCK")
        if [ -z "$want" ]; then
            printf '%s %s\n' "$1" "$got" >> "$LOCK"
            want="$got"
        fi
    fi
    if [ "$got" != "$want" ]; then
        echo "build-stack: sha256 mismatch for $file" >&2
        echo "  want $want" >&2
        echo "  got  $got" >&2
        exit 1
    fi
    echo "$file"
}

unpack() { # name -> prints source dir (fresh extraction every build)
    arc=$(fetch "$1")
    rm -rf "$W/src/$1"
    mkdir -p "$W/src/$1"
    tar -xf "$arc" -C "$W/src/$1"
    d=$(find "$W/src/$1" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -d "$HERE/patches/$1" ]; then
        for p in "$HERE/patches/$1"/*.patch; do
            [ -f "$p" ] || continue
            echo "  patch $(basename "$p")" >&2
            patch -d "$d" -p1 < "$p" >&2
        done
    fi
    echo "$d"
}

cleanup_la() { find "$SYS/usr/lib" -name '*.la' -delete 2>/dev/null || :; }

auto() { # name [configure args...]
    n="$1"; shift
    s=$(unpack "$n")
    # Old tarballs ship a config.sub that predates the *-linux-musl triple.
    for f in config.sub config.guess; do
        find "$s" -name "$f" -type f | while IFS= read -r old; do
            [ -f "/usr/share/misc/$f" ] && cp -f "/usr/share/misc/$f" "$old"
        done
    done
    b="$W/build/$n"; rm -rf "$b"; mkdir -p "$b"
    (cd "$b" && "$s/configure" --host=$TARGET --build=$BUILD_TRIPLE \
        --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
        --with-sysroot="$SYS" --disable-static --enable-shared \
        --disable-malloc0returnsnull "$@" \
        && make -j"$JOBS" && make DESTDIR="$SYS" install)
    cleanup_la
    # install dirs taken from .pc variables carry the sysroot prefix
    # (appdefaultdir, sdkdir): such a file lands under $SYS$SYS - stop here
    # rather than ship a tree named after the build machine
    if [ -e "$SYS$SYS" ]; then
        echo "auto: $n installed into $SYS$SYS (a sysroot-prefixed path from pkg-config)" >&2
        return 1
    fi
}

mes() { # name [meson args...]
    n="$1"; shift
    s=$(unpack "$n")
    b="$W/build/$n"; rm -rf "$b"
    "$MESON" setup "$b" "$s" --cross-file "$W/cross.ini" --prefix=/usr \
        --sysconfdir=/etc --localstatedir=/var --libdir=lib \
        --buildtype=release --default-library=shared --wrap-mode=nofallback "$@"
    # pkg-config prefixes every path variable with the sysroot, so runtime
    # paths taken from .pc files (Xorg's DRI driver dir, GTK's X11 locale
    # dir) would point into the build machine: strip it from the generated
    # config headers.
    find "$b" -maxdepth 2 -name '*config*.h' -type f -exec sed -i "s|$SYS/usr/|/usr/|g" {} +
    # ... and from -D values on compile lines (GTK's X11_DATA_PREFIX);
    # -I/-L paths are not quoted values and stay as they are
    sed -i "s|=\"$SYS/usr|=\"/usr|g" "$b/build.ninja"
    "$MESON" compile -C "$b" -j "$JOBS"
    DESTDIR="$SYS" "$MESON" install -C "$b" --no-rebuild
}

cmk() { # name [cmake args...]
    n="$1"; shift
    s=$(unpack "$n")
    b="$W/build/$n"; rm -rf "$b"
    cmake -G Ninja -S "$s" -B "$b" -DCMAKE_TOOLCHAIN_FILE="$W/toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib "$@"
    ninja -C "$b" -j "$JOBS"
    DESTDIR="$SYS" ninja -C "$b" install
}

# --- steps -------------------------------------------------------------------
step_musl() {
    s=$(unpack musl)
    (cd "$s" && ./configure --prefix=/usr --syslibdir=/lib --target=$TARGET \
        CC="$TC/bin/clang --target=$TARGET" \
        LIBCC="$("$TC/bin/clang" --target=$TARGET -rtlib=compiler-rt -print-libgcc-file-name)" \
        AR="$AR" RANLIB="$RANLIB" CFLAGS="-O2" \
        && make -j"$JOBS" && make DESTDIR="$SYS" install)
    # One loader: /lib/ld-musl-x86_64.so.1 -> /usr/lib/libc.so
    ln -sf ../usr/lib/libc.so "$SYS/lib/ld-musl-x86_64.so.1"
}

step_kheaders() {
    # the same kernel release build-kernel.sh builds
    kver="${KVER:-6.6.157}"
    ksrc="${KERNEL_SRC:-$W/src/linux/linux-$kver}"
    if [ ! -d "$ksrc" ] && [ -f "$TOP/../kernel/linux-$kver.tar.xz" ]; then
        mkdir -p "$W/src/linux" && tar -xf "$TOP/../kernel/linux-$kver.tar.xz" -C "$W/src/linux"
    fi
    [ -d "$ksrc" ] || { echo "kernel source not found: $ksrc (run stack/build-kernel.sh)" >&2; exit 1; }
    make -C "$ksrc" ARCH=x86_64 HOSTCC="${CC_FOR_BUILD}" O="$W/build/khdr" \
        INSTALL_HDR_PATH="$W/build/khdr/out" headers_install
    cp -a "$W/build/khdr/out/include/." "$SYS/usr/include/"
    # headers_install with O= skips the one-line asm-generic wrappers
    # (asm/types.h, asm/errno.h, ...); generate them the way Kbuild does.
    for g in "$SYS/usr/include/asm-generic"/*.h; do
        h=$(basename "$g")
        [ -e "$SYS/usr/include/asm/$h" ] && continue
        case "$h" in
            types.h|errno.h|ioctl.h|ioctls.h|ipcbuf.h|mman.h|msgbuf.h|param.h|poll.h|\
            resource.h|sembuf.h|shmbuf.h|siginfo.h|socket.h|sockios.h|stat.h|statfs.h|\
            swab.h|termbits.h|termios.h|fcntl.h|bpf_perf_event.h|kvm_para.h|unistd.h)
                printf '#include <asm-generic/%s>\n' "$h" > "$SYS/usr/include/asm/$h" ;;
        esac
    done
}

step_cxxrt() {
    llvm="$W/src/llvm-rt"
    if [ ! -d "$llvm/llvm-project-21.1.8.src" ]; then
        arc=$(fetch llvm-project)
        rm -rf "$llvm"; mkdir -p "$llvm"
        tar -xf "$arc" -C "$llvm" llvm-project-21.1.8.src/runtimes llvm-project-21.1.8.src/libcxx \
            llvm-project-21.1.8.src/libcxxabi llvm-project-21.1.8.src/libunwind \
            llvm-project-21.1.8.src/libc llvm-project-21.1.8.src/cmake \
            llvm-project-21.1.8.src/llvm/cmake llvm-project-21.1.8.src/llvm/utils \
            llvm-project-21.1.8.src/third-party
    fi
    b="$W/build/cxxrt"; rm -rf "$b"
    cmake -G Ninja -S "$llvm/llvm-project-21.1.8.src/runtimes" -B "$b" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
        -DCMAKE_C_COMPILER="$TC/bin/clang" -DCMAKE_CXX_COMPILER="$TC/bin/clang++" \
        -DCMAKE_ASM_COMPILER="$TC/bin/clang" \
        -DCMAKE_C_COMPILER_TARGET=$TARGET -DCMAKE_CXX_COMPILER_TARGET=$TARGET \
        -DCMAKE_ASM_COMPILER_TARGET=$TARGET -DCMAKE_SYSROOT="$SYS" \
        -DCMAKE_AR="$AR" -DCMAKE_RANLIB="$RANLIB" -DCMAKE_NM="$NM" \
        -DCMAKE_C_FLAGS="-rtlib=compiler-rt -unwindlib=none" \
        -DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -unwindlib=none" \
        -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" -DCMAKE_INSTALL_PREFIX=/usr \
        -DLIBCXX_HAS_MUSL_LIBC=ON -DLIBCXX_USE_COMPILER_RT=ON -DLIBCXX_HAS_ATOMIC_LIB=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXX_INCLUDE_TESTS=OFF \
        -DLIBCXXABI_USE_COMPILER_RT=ON -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DLIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=OFF -DLIBCXXABI_INCLUDE_TESTS=OFF \
        -DLIBUNWIND_USE_COMPILER_RT=ON -DLIBUNWIND_INCLUDE_TESTS=OFF \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    ninja -C "$b" -j "$JOBS"
    DESTDIR="$SYS" ninja -C "$b" install
}

step_zlib() {
    s=$(unpack zlib)
    (cd "$s" && CHOST=$TARGET ./configure --prefix=/usr --shared && make -j"$JOBS" && make DESTDIR="$SYS" install)
}
step_libffi()   { auto libffi --disable-docs; }
step_pcre2()    { auto pcre2 --enable-pcre2-16 --enable-pcre2-32; }
step_expat()    { auto expat --without-docbook --without-examples --without-tests; }
step_libpng()   { auto libpng; }
step_libjpeg()  { cmk libjpeg-turbo -DENABLE_STATIC=OFF -DWITH_JPEG8=ON; }
step_freetype() { mes freetype -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=enabled -Dzlib=enabled -Dtests=disabled; }
step_fontconfig() { mes fontconfig -Ddoc=disabled -Dtests=disabled -Dtools=enabled -Dcache-build=disabled -Dnls=disabled; }
step_pixman()   { mes pixman -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled; }
step_libmd()    { auto libmd; }

# X11 client side
step_util_macros() { auto util-macros; }
step_xorgproto()   { mes xorgproto -Dlegacy=true; }
step_xcb_proto()   { auto xcb-proto; }
step_libXau()      { auto libXau; }
step_libXdmcp()    { auto libXdmcp; }
step_xtrans()      { auto xtrans; }
step_libxcb() {
    # xcbgen lives in the sysroot; point configure at it directly.
    pyd=$(find "$SYS/usr/lib" -maxdepth 3 -type d -name site-packages | head -1)
    XCBPROTO_XCBINCLUDEDIR="$SYS/usr/share/xcb" XCBPROTO_XCBPYTHONDIR="$pyd" \
    PYTHONPATH="$pyd" auto libxcb --without-doxygen --disable-devel-docs
}
step_libX11()      { auto libX11 --disable-specs --enable-ipv6 --without-xmlto; }
step_libXext()     { auto libXext --disable-specs --without-xmlto; }
step_libXrender()  { auto libXrender; }
step_libXfixes()   { auto libXfixes; }
step_libXi()       { auto libXi --disable-specs --disable-docs; }
step_libXrandr()   { auto libXrandr; }
step_libXcursor()  { auto libXcursor; }
step_libXcomposite() { auto libXcomposite; }
step_libXdamage()  { auto libXdamage; }
step_libXinerama() { auto libXinerama; }
step_libXtst()     { auto libXtst --disable-specs; }
step_libICE()      { auto libICE --disable-specs --disable-docs; }
step_libSM()       { auto libSM --disable-docs; }
step_libXt()       { auto libXt --disable-specs; }
step_libXmu()      { auto libXmu --disable-docs; }
step_libXft()      { auto libXft; }
step_libXpm()      { auto libXpm --disable-open-zfile; }
step_libxkbfile()  { mes libxkbfile; }
step_libfontenc()  { auto libfontenc; }
step_libXfont2()   { auto libXfont2 --disable-devel-docs; }
step_libxshmfence() { auto libxshmfence; }
step_libpciaccess() { mes libpciaccess -Dzlib=enabled; }
step_libdrm() {
    mes libdrm -Dintel=enabled -Dradeon=enabled -Damdgpu=enabled -Dnouveau=enabled \
        -Dvmwgfx=disabled -Dcairo-tests=disabled -Dman-pages=disabled -Dvalgrind=disabled -Dtests=false
}
step_libxcvt()     { mes libxcvt; }

# Xorg
step_mtdev()       { auto mtdev; }
step_libevdev()    { mes libevdev -Dtests=disabled -Ddocumentation=disabled; }
step_libudev_zero() {
    s=$(unpack libudev-zero)
    (cd "$s" && make -j"$JOBS" CC="$CC" AR="$AR" PREFIX=/usr \
        && make DESTDIR="$SYS" PREFIX=/usr install)
}
step_xorg_server() {
    mes xorg-server -Dxorg=true -Dxvfb=false -Dxnest=false -Dxephyr=false -Dxwin=false \
        -Dxquartz=false -Dglamor=true -Dglx=true -Ddri1=false -Ddri2=true -Ddri3=true \
        -Dudev=true -Dudev_kms=false -Dsystemd_logind=false -Dsuid_wrapper=false \
        -Dint10=false -Dvgahw=false -Dxdmcp=false -Dsecure-rpc=false -Dlibunwind=false \
        -Dxselinux=false -Dxcsecurity=false -Ddtrace=false -Ddocs=false -Ddevel-docs=false \
        -Dsha1=libmd -Dhal=false -Dlinux_apm=false -Dlinux_acpi=false \
        -Dxkb_dir=/usr/share/X11/xkb -Dxkb_output_dir=/var/lib/xkb -Dxkb_bin_dir=/usr/bin \
        -Ddefault_font_path=/usr/share/fonts/X11/misc,built-ins \
        -Dlog_dir=/var/log -Dmodule_dir=/usr/lib/xorg/modules
}
step_xf86_video_fbdev() { auto xf86-video-fbdev --disable-pciaccess; }
step_xf86_input_evdev() { auto xf86-input-evdev; }
step_xkbcomp()     { auto xkbcomp; }
# libinput is the input driver (evdev 2.10 segfaults on keyboard init here).
step_libinput() {
    mes libinput -Dlibwacom=false -Ddebug-gui=false -Dtests=false -Ddocumentation=false \
        -Dudev-dir=/lib/udev
}
step_xf86_input_libinput() { auto xf86-input-libinput --with-sdkdir=/usr/include/xorg; }

# GTK
step_glib() {
    mes glib -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dintrospection=disabled \
        -Dtests=false -Dman-pages=disabled -Dsysprof=disabled -Ddocumentation=false \
        -Dnls=disabled -Dglib_debug=disabled
}
# Build tools other packages locate via pkg-config (glib-compile-resources,
# gdk-pixbuf-pixdata, ...) are target binaries; keep them runnable on the build
# host by parking the ELF under usr/libexec/flx-target and putting a musl-run
# wrapper in its place.  install-stack.sh never copies these wrappers.
wrap_target_bins() {
    mkdir -p "$SYS/usr/libexec/flx-target"
    for b in "$@"; do
        f="$SYS/usr/bin/$b"
        [ -f "$f" ] || continue
        head -c 4 "$f" | grep -q ELF || continue
        mv -f "$f" "$SYS/usr/libexec/flx-target/$b"
        printf '#!/bin/sh\nexec "%s" "%s" "$@"\n' "$W/bin/musl-run" "$SYS/usr/libexec/flx-target/$b" > "$f"
        chmod +x "$f"
    done
}
step_glib_tools() {
    wrap_target_bins glib-compile-resources glib-compile-schemas gio-querymodules \
        gdbus gio gresource gsettings
}
step_pixbuf_tools() {
    wrap_target_bins gdk-pixbuf-csource gdk-pixbuf-pixdata gdk-pixbuf-query-loaders gdk-pixbuf-thumbnailer
}
step_fribidi()    { mes fribidi -Ddocs=false -Dbin=false -Dtests=false; }
step_harfbuzz() {
    mes harfbuzz -Dglib=enabled -Dfreetype=enabled -Dcairo=disabled -Dicu=disabled \
        -Dgobject=disabled -Dintrospection=disabled -Dtests=disabled -Ddocs=disabled \
        -Dutilities=disabled -Dbenchmark=disabled
}
step_cairo() {
    mes cairo -Dxlib=enabled -Dxcb=enabled -Dtee=enabled -Dpng=enabled -Dzlib=enabled \
        -Dglib=enabled -Dtests=disabled -Dgtk_doc=false -Dspectre=disabled \
        -Dlzo=disabled -Dgtk2-utils=disabled -Dsymbol-lookup=disabled
}
step_pango() {
    mes pango -Dintrospection=disabled -Dfontconfig=enabled -Dfreetype=enabled \
        -Dxft=enabled -Dcairo=enabled -Dbuild-testsuite=false -Dbuild-examples=false \
        -Ddocumentation=false -Dman-pages=false -Dsysprof=disabled -Dlibthai=disabled
}
step_gdk_pixbuf() {
    mes gdk-pixbuf -Dpng=enabled -Djpeg=enabled -Dtiff=disabled -Dgif=enabled \
        -Dothers=disabled -Dintrospection=disabled -Dman=false -Dgtk_doc=false \
        -Dbuiltin_loaders=all -Dtests=false -Dinstalled_tests=false -Dgio_sniffing=false
}
step_atk()         { mes atk -Dintrospection=false -Ddocs=false; }
step_libxml2()     { auto libxml2 --without-python --without-icu --without-lzma --without-readline --without-history --without-http --without-debug; }
# GTK3's X11 backend requires atk-bridge; at-spi2-core provides atk, atspi
# and the bridge (it supersedes the standalone atk tarball).
step_at_spi2_core() {
    mes at-spi2-core -Dintrospection=disabled -Ddocs=false -Duse_systemd=false \
        -Dx11=enabled -Ddbus_daemon=/usr/bin/dbus-daemon -Ddefault_bus=dbus-daemon
}
step_libepoxy()    { mes libepoxy -Degl=yes -Dglx=yes -Dx11=true -Dtests=false -Ddocs=false; }
step_gtk3() {
    mes gtk -Dx11_backend=true -Dwayland_backend=false -Dbroadway_backend=false \
        -Dintrospection=false -Ddemos=false -Dexamples=false -Dtests=false \
        -Dinstalled_tests=false -Dprint_backends=file -Dcolord=no -Dcloudproviders=false \
        -Dtracker3=false -Dman=false -Dgtk_doc=false -Dxinerama=yes \
        -Dbuiltin_immodules=yes
}
step_alsa_lib()    { auto alsa-lib --disable-python --disable-topology --without-debug; }

# Userland that was shipped GCC-contaminated or built against old static deps
step_openssl() {
    s=$(unpack openssl)
    (cd "$s" && ./Configure linux-x86_64 --prefix=/usr --openssldir=/etc/ssl --libdir=lib \
        shared no-tests no-docs CC="$CC" AR="$AR" RANLIB="$RANLIB" \
        && make -j"$JOBS" && make DESTDIR="$SYS" install_sw install_ssldirs)
}
# sqlite's configure is autosetup since 3.48 (no autoconf-style options);
# its bootstrap jimsh is built for the host as a static musl binary
step_sqlite() {
    s=$(unpack sqlite)
    b="$W/build/sqlite"; rm -rf "$b"; mkdir -p "$b"
    (cd "$b" && CC_FOR_BUILD="$CC -static" BUILD_CC="$CC -static" "$s/configure" \
        --host=$TARGET --build=$BUILD_TRIPLE --prefix=/usr --disable-static \
        --disable-readline --disable-static-shell --soname=legacy \
        && make -j"$JOBS" && make DESTDIR="$SYS" install)
}
step_libnl()   { auto libnl --disable-cli --disable-debug; }
step_dbus() {
    mes dbus -Dsystemd=disabled -Dx11_autolaunch=disabled -Dmodular_tests=disabled \
        -Ddoxygen_docs=disabled -Dxml_docs=disabled -Dducktype_docs=disabled \
        -Dqt_help=disabled -Dselinux=disabled -Dapparmor=disabled -Dlibaudit=disabled \
        -Dinotify=enabled -Depoll=enabled -Dmessage_bus=true -Dtools=true \
        -Dsystem_socket=/run/dbus/system_bus_socket -Druntime_dir=/run
}
step_wpa_supplicant() {
    s=$(unpack wpa_supplicant)
    cd "$s/wpa_supplicant"
    {
        echo 'CONFIG_DRIVER_NL80211=y'; echo 'CONFIG_LIBNL32=y'
        echo 'CONFIG_CTRL_IFACE=y'; echo 'CONFIG_CTRL_IFACE_UNIX=y'
        echo 'CONFIG_BACKEND=file'; echo 'CONFIG_NO_RANDOM_POOL=y'
        echo 'CONFIG_TLS=openssl'; echo 'CONFIG_SAE=y'; echo 'CONFIG_IEEE80211W=y'
        echo 'CONFIG_IEEE8021X_EAPOL=y'; echo 'CONFIG_EAP_PEAP=y'; echo 'CONFIG_EAP_TTLS=y'
        echo 'CONFIG_EAP_MSCHAPV2=y'; echo 'CONFIG_EAP_TLS=y'; echo 'CONFIG_EAP_GTC=y'
        echo 'CONFIG_EAP_MD5=y'; echo 'CONFIG_EAP_OTP=y'; echo 'CONFIG_EAP_LEAP=y'
    } > .config
    make -j"$JOBS" CC="$CC" PKG_CONFIG="$PKG_CONFIG" \
        EXTRA_CFLAGS="-I$SYS/usr/include/libnl3" BINDIR=/sbin
    make DESTDIR="$SYS" BINDIR=/sbin install
}
step_flxnet() {
    # flxifconfig / flxroute: FreeLinX's own netlink ifconfig/route.
    mkdir -p "$SYS/sbin"
    for t in ifconfig route; do
        "$CC" -O2 -I"$SYS/usr/include/libnl3" -o "$SYS/sbin/flx$t" \
            "$TOP/ports/net/freelinx-$t/$t.c" -lnl-route-3 -lnl-3
    done
}
step_xpkg() {
    xs="${XPKG_SRC:-$TOP/../xpkg}"
    b="$W/build/xpkg"; rm -rf "$b"; mkdir -p "$b"
    for c in "$xs"/src/*.c; do
        "$CC" -O2 -I"$xs/include" -c -o "$b/$(basename "$c" .c).o" "$c"
    done
    mkdir -p "$SYS/usr/bin"
    "$CC" -o "$SYS/usr/bin/xpkg" "$b"/*.o -lsqlite3 -lz -lssl -lcrypto
}
# --- curses: NetBSD curses (BSD), not GNU ncurses ----------------------------
# libcurses/libterminfo/libform/libmenu/libpanel, wide-char.  The install adds
# the ncurses names (libncursesw.so, ncursesw.pc, ...) so nnn, alsamixer and
# libedit find it unchanged.  The terminfo database is one CDB file,
# /usr/share/terminfo.cdb, read by these libraries and by the base system's
# libterminfo alike; xterm, linux, screen, tmux, st and rxvt-unicode are also
# compiled into libterminfo.  (The descriptions themselves are the terminfo
# data every BSD ships, maintained upstream by Thomas E. Dickey.)
step_netbsd_curses() {
    # a sysroot that had GNU ncurses: remove all of it first
    rm -rf "$SYS/usr/lib/terminfo" "$SYS/usr/share/terminfo" "$SYS/usr/share/tabset" \
        "$SYS/usr/bin/ncursesw6-config" "$SYS"/usr/lib/lib*w.so.6* \
        "$SYS"/usr/lib/libtinfo* "$SYS"/usr/lib/libncurses* \
        "$SYS"/usr/lib/pkgconfig/ncurses*.pc "$SYS"/usr/lib/pkgconfig/tinfo*.pc \
        "$SYS"/usr/include/ncurses_dll.h "$SYS"/usr/include/term_entry.h
    for t in captoinfo infotocap toe reset tic tput tset infocmp clear tabs; do
        rm -f "$SYS/usr/bin/$t"
    done
    s=$(unpack netbsd-curses)
    cd "$s"
    m() {
        make -f GNUmakefile HOSTCC="$CC -static" CC="$CC" AR="$AR" RANLIB="${RANLIB:-$AR s}" \
            CFLAGS="-O2 -fPIC -DTERMINFO_COMPAT" \
            CFLAGS_HOST="-O2 -DTERMINFO_COMPAT" PREFIX=/usr "$@"
    }
    m -j"$JOBS" all
    m DESTDIR="$SYS" install-headers install-libs install-progs install-pcs
    # the database: NetBSD 10's terminfo source, compiled by the image's own
    # NetBSD 10 tic (netbsd-curses' older tic misreads e.g. colors#0x100)
    "$TOP/src/rootfs/bin/tic" -x -o "$SYS/usr/share/terminfo.cdb" "$(fetch netbsd-terminfo)"
    chmod 644 "$SYS/usr/share/terminfo.cdb"
    mkdir -p "$SYS/usr/share/misc"
    ln -sf ../terminfo.cdb "$SYS/usr/share/misc/terminfo.cdb"
    # names asked for by software written for ncurses' split libraries
    ln -sf libterminfo.so "$SYS/usr/lib/libtinfo.so"
    ln -sf libterminfo.so "$SYS/usr/lib/libtinfow.so"
    ln -sf terminfo.pc "$SYS/usr/lib/pkgconfig/tinfo.pc"
    ln -sf ncursesw.pc "$SYS/usr/lib/pkgconfig/ncursesw6.pc"
    mkdir -p "$SYS/usr/include/ncursesw"
    for h in curses.h ncurses.h term.h termcap.h unctrl.h panel.h menu.h eti.h form.h; do
        ln -sf "../$h" "$SYS/usr/include/ncursesw/$h"
    done
}
step_musl_fts() {
    # NetBSD fts(3), packaged for musl by Void; a single source file.
    s=$(unpack musl-fts)
    # What its configure would find on musl.
    printf '#define HAVE_DIRFD 1\n#define HAVE_DECL_MAX 1\n#define HAVE_DECL_UINTMAX_MAX 1\n' > "$s/config.h"
    "$CC" -O2 -fPIC -I"$s" -c -o "$W/build/fts.o" "$s/fts.c"
    "$AR" rcs "$SYS/usr/lib/libfts.a" "$W/build/fts.o"
    cp -f "$s/fts.h" "$SYS/usr/include/fts.h"
}
step_nnn() {
    s=$(unpack nnn)
    (cd "$s" && make -j"$JOBS" CC="$CC" PKG_CONFIG="$PKG_CONFIG" O_NORL=1 O_NOMOUSE=0 \
        LDLIBS_CURSES="$("$PKG_CONFIG" --libs ncursesw) -lfts" \
        && make DESTDIR="$SYS" PREFIX=/usr install)
}
step_imlib2() {
    auto imlib2 --without-id3 --without-heif --without-jxl --without-webp --without-tiff \
        --without-bz2 --without-lzma --without-y4m --without-ps --without-svg --without-j2k \
        --without-avif --without-raw --without-x-shm-fd
}
step_tint2() {
    cmk tint2 -DENABLE_RSVG=OFF -DENABLE_SN=OFF -DENABLE_TINT2CONF=OFF \
        -DENABLE_BATTERY=ON -DENABLE_UEVENT=OFF -DENABLE_EXTRA_THEMES=OFF
}
step_alsa_utils() {
    auto alsa-utils --disable-nls --disable-xmlto --disable-rst2man --disable-bat \
        --disable-alsaconf --disable-alsaloop --with-curses=ncursesw \
        --with-udev-rules-dir=/lib/udev/rules.d --with-systemdsystemunitdir=no
}
step_libXaw()  { auto libXaw --disable-specs --disable-xaw6; }
step_xcalc()   { auto xcalc --with-appdefaultdir=/usr/share/X11/app-defaults; }

# IANA time zone database, compiled with the build host's zic (data only).
step_tzdata() {
    unpack tzdata >/dev/null; s="$W/src/tzdata"  # flat tarball, no top dir
    rm -rf "$SYS/usr/share/zoneinfo"; mkdir -p "$SYS/usr/share/zoneinfo"
    (cd "$s" && /usr/sbin/zic -b slim -d "$SYS/usr/share/zoneinfo" \
        africa antarctica asia australasia europe northamerica southamerica etcetera backward)
    cp -f "$s/zone1970.tab" "$s/iso3166.tab" "$SYS/usr/share/zoneinfo/"
}
# FreeLinX's own cairo/X11 apps, linked against this stack (the old static
# builds used a cairo without a font backend: every text call was a no-op).
step_flxapps() {
    mkdir -p "$SYS/usr/bin"
    "$CC" -O2 $("$PKG_CONFIG" --cflags cairo x11) -o "$SYS/usr/bin/flxinstall-gui" \
        "$TOP/flxinstall-gui.c" $("$PKG_CONFIG" --libs cairo x11)
    "$CC" -O2 $("$PKG_CONFIG" --cflags cairo x11) -o "$SYS/usr/bin/flxnetmgr" \
        "$TOP/flxnetmgr.c" $("$PKG_CONFIG" --libs cairo x11)
    "$CC" -O2 -Wall $("$PKG_CONFIG" --cflags gtk+-3.0) -o "$SYS/usr/bin/flxpkg" \
        "$TOP/flxpkg.c" $("$PKG_CONFIG" --libs gtk+-3.0)
}

# toybox (0BSD): only the process/system tools NetBSD's userland cannot
# provide on Linux (NetBSD ps/top need kvm and sys/lwp.h).
TOYBOX_APPLETS="ps top free uptime pgrep pkill pidof w getty login setsid"
step_toybox() {
    s=$(unpack toybox)
    cd "$s"
    : > flx-mini.config
    for t in $TOYBOX_APPLETS; do
        echo "CONFIG_$(echo "$t" | tr a-z A-Z)=y" >> flx-mini.config
    done
    make allnoconfig KCONFIG_ALLCONFIG=flx-mini.config >/dev/null
    # host helpers (kconfig, mkflags) are static musl binaries: no host compiler
    make toybox CC="$CC" CFLAGS="-O2" LDFLAGS="" HOSTCC="$CC -static"
    mkdir -p "$SYS/usr/bin"
    install -m755 toybox "$SYS/usr/bin/toybox"
    for t in $TOYBOX_APPLETS; do ln -sf toybox "$SYS/usr/bin/$t"; done
}

# --- GPU acceleration: Mesa 24.0 (the last series whose iris needs no
# OpenCL/LLVM toolchain; no LLVM: iris/crocus/i915 for Intel, nouveau,
# r300/r600 for older AMD, virgl for VMs, softpipe as the CPU fallback) ------
step_libXxf86vm() { auto libXxf86vm; }
# Mesa's Intel drivers (iris, crocus) ship shaders written in OpenCL C,
# compiled at build time by mesa_clc (clang + SPIRV-LLVM-Translator).  Those
# are build machine tools, like llvm-tblgen: step_mesa_clc_host builds them
# natively into $W/host-clc, and nothing from there goes into the image.
step_mesa_clc_host() {
    H="$W/host-clc"; rm -rf "$H"; mkdir -p "$H"
    # LLVM + clang 18 for the build machine (the X86 backend only: clang
    # needs one; SPIR-V comes from the translator)
    s=$(unpack llvm18)
    b="$W/build/llvm18-clc"; rm -rf "$b"
    cmake -G Ninja -S "$s/llvm" -B "$b" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ -DCMAKE_INSTALL_PREFIX="$H" \
        -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD=X86 \
        -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCLANG_LINK_CLANG_DYLIB=ON \
        -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_INSTALL_UTILS=ON -DLLVM_ENABLE_ASSERTIONS=OFF
    ninja -C "$b" -j "$JOBS" install
    # SPIR-V headers and tools
    hs=$(unpack spirv-headers)
    cmake -G Ninja -S "$hs" -B "$W/build/spirv-headers" -DCMAKE_INSTALL_PREFIX="$H"
    ninja -C "$W/build/spirv-headers" install
    ts=$(unpack spirv-tools)
    cmake -G Ninja -S "$ts" -B "$W/build/spirv-tools" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ -DCMAKE_INSTALL_PREFIX="$H" \
        -DCMAKE_INSTALL_LIBDIR=lib -DSPIRV-Headers_SOURCE_DIR="$hs" \
        -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_WERROR=OFF
    ninja -C "$W/build/spirv-tools" -j "$JOBS" install
    # SPIRV-LLVM-Translator, against the headers revision it pins
    ls=$(unpack spirv-llvm-translator)
    lh=$(unpack spirv-headers-llvmspirv)
    cmake -G Ninja -S "$ls" -B "$W/build/spirv-llvm-translator" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ -DCMAKE_INSTALL_PREFIX="$H" \
        -DCMAKE_INSTALL_LIBDIR=lib -DLLVM_DIR="$H/lib/cmake/llvm" \
        -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR="$lh" -DLLVM_SPIRV_INCLUDE_TESTS=OFF \
        -DBUILD_SHARED_LIBS=OFF
    ninja -C "$W/build/spirv-llvm-translator" -j "$JOBS" install
    # mesa_clc and vtn_bindgen2 themselves, from the same Mesa source
    ms=$(unpack mesa)
    mb="$W/build/mesa-clc-host"; rm -rf "$mb"
    env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS -u PKG_CONFIG -u PKG_CONFIG_PATH \
        -u PKG_CONFIG_LIBDIR -u PKG_CONFIG_SYSROOT_DIR \
        PKG_CONFIG_PATH="$H/lib/pkgconfig:$H/share/pkgconfig" PATH="$H/bin:$PATH" \
        "$MESON" setup "$mb" "$ms" --prefix="$H" --libdir=lib --buildtype=release \
        -Dplatforms= -Dgallium-drivers= -Dvulkan-drivers= -Dglx=disabled -Degl=disabled \
        -Dgbm=disabled -Dopengl=false -Dgles1=disabled -Dgles2=disabled \
        -Dllvm=enabled -Dshared-llvm=enabled -Dmesa-clc=enabled -Dinstall-mesa-clc=true \
        -Dvalgrind=disabled -Dlibunwind=disabled -Dzstd=disabled -Dbuild-tests=false \
        -Dexpat=disabled -Dxmlconfig=disabled
    env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS LD_LIBRARY_PATH="$H/lib" \
        ninja -C "$mb" -j "$JOBS" install
    test -x "$H/bin/mesa_clc" && test -x "$H/bin/vtn_bindgen2"
}
step_mesa() {
    test -x "$W/host-clc/bin/mesa_clc" || { echo "build mesa_clc_host first" >&2; return 1; }
    # mesa_clc runs on the build machine against its own LLVM/clang (in a
    # subshell: no later step may find the host llvm-config)
    ( export PATH="$W/host-clc/bin:$PATH" LD_LIBRARY_PATH="$W/host-clc/lib"
    mes mesa -Dplatforms=x11 -Dgallium-drivers=iris,crocus,i915,nouveau,r300,r600,radeonsi,virgl,llvmpipe,softpipe \
        -Dvulkan-drivers= -Dllvm=enabled -Dshared-llvm=enabled -Dglx=dri -Degl=enabled \
        -Dgbm=enabled -Dgles1=disabled -Dgles2=enabled -Dopengl=true -Dglvnd=disabled \
        -Dvalgrind=disabled -Dlibunwind=disabled -Dbuild-tests=false -Dgallium-va=enabled -Dva-libs-path=/usr/lib/dri \
        -Dvideo-codecs=vc1dec,h264dec,h265dec,av1dec,vp9dec -Dlmsensors=disabled -Dzstd=disabled \
        -Dmesa-clc=system -Dprecomp-compiler=system -Dmicrosoft-clc=disabled )
}
# --- LLVM 18 for Mesa (radeonsi needs the AMDGPU backend; llvmpipe the X86
# JIT).  Mesa 24.0 does not build against LLVM 19+, hence 18, separate from
# the 21.x toolchain.  llvm-tblgen is a build-time tool built for the host.
step_llvm18() {
    s=$(unpack llvm18)
    hb="$W/build/llvm18-host"; rm -rf "$hb"
    cmake -G Ninja -S "$s/llvm" -B "$hb" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ -DLLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
        -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBEDIT=OFF >/dev/null
    ninja -C "$hb" -j "$JOBS" llvm-tblgen
    b="$W/build/llvm18"; rm -rf "$b"
    cmake -G Ninja -S "$s/llvm" -B "$b" -DCMAKE_TOOLCHAIN_FILE="$W/toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DLLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
        -DLLVM_HOST_TRIPLE=x86_64-unknown-linux-musl -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl \
        -DLLVM_TABLEGEN="$hb/bin/llvm-tblgen" \
        -DCROSS_TOOLCHAIN_FLAGS_NATIVE="-DCMAKE_C_COMPILER=cc;-DCMAKE_CXX_COMPILER=c++" \
        -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_BUILD_UTILS=OFF -DLLVM_INSTALL_UTILS=OFF -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_ZLIB=ON -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF \
        -DLLVM_ENABLE_BINDINGS=OFF -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_LIBCXX=ON \
        -DLLVM_ENABLE_PIC=ON -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DHAVE_UNW_ADD_DYNAMIC_FDE=1
    # the NATIVE sub-build (host llvm-config/tblgen) must not see the target CC
    env -u CC -u CXX -u CFLAGS -u CXXFLAGS ninja -C "$b" -j "$JOBS" LLVM llvm-config
    DESTDIR="$SYS" ninja -C "$b" install
    install -m755 "$b/bin/llvm-config" "$SYS/usr/bin/llvm-config"
}

# --- libelf (elftoolchain, BSD): radeonsi's shader loader (ac_rtld) needs it.
# elfutils would bring GNU argp/obstack/fts; elftoolchain's libelf is plain C.
# Built directly (its build system is BSD make).
step_libelf() {
    s=$(unpack elftoolchain)
    cd "$s/libelf"
    printf '#define ELFTC_CLASS ELFCLASS64\n#define ELFTC_ARCH EM_X86_64\n#define ELFTC_BYTEORDER ELFDATA2LSB\n' \
        > ../common/native-elf-format.h
    for g in libelf_fsize libelf_msize libelf_convert; do
        m4 -D SRCDIR=. "$g.m4" > "$g.c"
    done
    # sys/queue.h (and sys/cdefs.h) from the FreeLinX NetBSD compat layer
    "$CC" -O2 -fPIC -shared -I. -I../common -idirafter "$TOP/../ports/base/compat" -Wl,-soname,libelf.so.1 \
        -o libelf.so.1 ./*.c
    install -m755 libelf.so.1 "$SYS/usr/lib/libelf.so.1"
    ln -sf libelf.so.1 "$SYS/usr/lib/libelf.so"
    install -m644 libelf.h gelf.h ../common/elfdefinitions.h "$SYS/usr/include/"
    # Mesa's ac_rtld uses STN_UNDEF, which this elfdefinitions.h lacks
    printf '\n#ifndef STN_UNDEF\n#define STN_UNDEF 0\n#endif\n' >> "$SYS/usr/include/elfdefinitions.h"
    v=$(basename "$s" | sed 's/elftoolchain-//')
    printf 'prefix=/usr\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\nName: libelf\nDescription: ELF object file access library (elftoolchain)\nVersion: %s\nLibs: -L${libdir} -lelf\nCflags: -I${includedir}\n' "$v" \
        > "$SYS/usr/lib/pkgconfig/libelf.pc"
}

# --- VA-API: hardware video decoding (libva; Mesa's VA for AMD/NVIDIA,
# intel-media-driver for Intel Gen8+, intel-vaapi-driver for older Intel) ---
step_libva() {
    mes libva -Ddriverdir=/usr/lib/dri -Dwith_x11=yes -Dwith_glx=no -Dwith_wayland=no
}
step_libva_utils() { auto libva-utils --disable-wayland --enable-x11 --enable-drm --disable-tests; }
step_gmmlib()   { cmk gmmlib -DRUN_TEST_SUITE=OFF; }
step_media_driver() {
    cmk media-driver -DINSTALL_DRIVER_SYSCONF=OFF -DMEDIA_BUILD_FATAL_WARNINGS=OFF \
        -DENABLE_NONFREE_KERNELS=ON -DBUILD_TYPE=release -DLIBVA_DRIVERS_PATH=/usr/lib/dri \
        -DCMAKE_C_FLAGS="-O2 -Wno-error" -DCMAKE_CXX_FLAGS="-O2 -Wno-error"
}
step_intel_vaapi() { mes intel-vaapi-driver -Ddriverdir=/usr/lib/dri -Dwith_x11=yes -Dwith_wayland=no; }

# --- glxinfo/glxgears from mesa-demos: compiled directly (only these two
# tools are wanted, and they need nothing beyond libGL and libX11) ---
step_mesa_demos() {
    s=$(unpack mesa-demos)
    cd "$s/src/xdemos"
    "$CC" -O2 -o glxgears glxgears.c -lGL -lX11 -lm
    "$CC" -O2 -I. -I../util -I../glad/include -o glxinfo glxinfo.c ../util/glinfo_common.c \
        ../glad/src/glad.c -lGL -lX11
    install -m755 glxgears glxinfo "$SYS/usr/bin/"
}

# --- X11 desktop programs, linked to the stack's shared libraries -----------
# (1.0.x shipped these as static binaries from an older build tree: their own
# copies of libX11/expat/freetype, and X11 locale paths of that build host.)
# Mozilla's CA certificates, as curl.se publishes them (dated, checksummed)
step_ca_certificates() {
    mkdir -p "$SYS/usr/share/ca-certificates"
    install -m644 "$(fetch ca-certificates)" "$SYS/usr/share/ca-certificates/cacert.pem"
}
# FreeLinX's own small X11 tools (FreeLinX/src/apps): screenshot, panel, flxfs
step_flx_x11_tools() {
    a="$TOP/../src/apps"
    "$CC" -O2 -o "$SYS/usr/bin/flxshot" "$a/flxshot.c" $("$PKG_CONFIG" --cflags --libs x11 cairo)
    "$CC" -O2 -o "$SYS/usr/bin/flxpanel" "$a/flxpanel.c" $("$PKG_CONFIG" --cflags --libs x11 cairo)
    "$CC" -O2 -o "$SYS/usr/bin/flxfs" "$a/flxfs.c"
}
step_libconfuse() { auto libconfuse --disable-examples --disable-nls; }
step_yajl()       { cmk yajl; }
step_i3status() {
    mes i3status -Dpulseaudio=false -Dmans=false
}
step_xbitmaps()  { auto xbitmaps; }
step_openbox() {
    auto openbox --disable-nls --disable-startup-notification --disable-librsvg \
        --enable-imlib2 --enable-xinerama --enable-xrandr --enable-xcursor
}
step_xsetroot()  { auto xsetroot; }
step_xrandr()    { auto xrandr; }
step_setxkbmap() { auto setxkbmap; }
step_xinit()     { auto xinit --with-xinitdir=/etc/X11/xinit; }
step_xeyes()     { auto xeyes; }
step_xclock()    { auto xclock --with-appdefaultdir=/usr/share/X11/app-defaults; }
step_xmag()      { auto xmag --with-appdefaultdir=/usr/share/X11/app-defaults; }
step_xclip() {
    s=$(unpack xclip)
    cd "$s"
    "$CC" -O2 -DPACKAGE_NAME=\"xclip\" -DPACKAGE_VERSION=\"0.13\" -o xclip xclip.c xclib.c xcprint.c -lXmu -lX11
    install -m755 xclip xclip-copyfile xclip-pastefile xclip-cutfile "$SYS/usr/bin/" 2>/dev/null \
        || install -m755 xclip "$SYS/usr/bin/xclip"
}
suckless() { # name [make vars...]
    s=$(unpack "$1"); shift
    cd "$s"
    make -j"$JOBS" CC="$CC" PKG_CONFIG="$PKG_CONFIG" PREFIX=/usr \
        X11INC="$SYS/usr/include" X11LIB="$SYS/usr/lib" \
        FREETYPEINC="$SYS/usr/include/freetype2" "$@"
    make PREFIX=/usr DESTDIR="$SYS" "$@" install
}
step_dwm()      { suckless dwm; }
step_dmenu()    { suckless dmenu; }
step_st()       { suckless st TERMINFO=/nonexistent; }
step_slstatus() { suckless slstatus; }
step_nsxiv() {
    s=$(unpack nsxiv)
    cd "$s"
    make -j"$JOBS" CC="$CC" PKG_CONFIG="$PKG_CONFIG" PREFIX=/usr \
        HAVE_LIBEXIF=0 HAVE_LIBGIF=0 HAVE_LIBWEBP=0 HAVE_INOTIFY=1 HAVE_LIBFONTS=1
    make PREFIX=/usr DESTDIR="$SYS" install-all
}
step_feh() {
    s=$(unpack feh)
    cd "$s"
    # no libcurl or libexif in the stack: local files only, no EXIF view
    # CFLAGS from the environment: on the command line it would replace feh's
    # own -D flags instead of being appended to
    CFLAGS="-O2 $(pkg-config --cflags imlib2 x11)" make -j"$JOBS" CC="$CC" PREFIX=/usr \
        curl=0 exif=0 magic=0 xinerama=1 inotify=1 verscmp=1 app=0
    make PREFIX=/usr DESTDIR="$SYS" curl=0 exif=0 magic=0 xinerama=1 inotify=1 install
}
step_libptytty() { cmk libptytty -DBUILD_SHARED_LIBS=ON -DUTMP_SUPPORT=OFF -DWTMP_SUPPORT=OFF -DLASTLOG_SUPPORT=OFF; }
step_rxvt_unicode() {
    auto rxvt-unicode --disable-perl --enable-xft --enable-font-styles --enable-256-color \
        --enable-unicode3 --enable-combining --enable-fading --enable-transparency \
        --enable-pixbuf=no --disable-startup-notification --disable-utmp --disable-wtmp \
        --disable-lastlog
}
step_doomgeneric() {
    s=$(unpack doomgeneric)
    cd "$s/doomgeneric"
    make -f Makefile -j"$JOBS" CC="$CC" CFLAGS="-O2 -DNORMALUNIX -DLINUX -DSNDSERV -D_DEFAULT_SOURCE" \
        LIBS="-lX11 -lm" OUTPUT=doom
    mkdir -p "$SYS/usr/lib/doom"
    install -m755 doom "$SYS/usr/lib/doom/doomgeneric"
    # doomgeneric only looks for its IWAD in the current directory
    printf '#!/bin/sh\n# Doom (doomgeneric) with the shareware or a user-supplied IWAD\nwad="${DOOMWAD:-/usr/share/games/doom/doom1.wad}"\ncase " $* " in *" -iwad "*) exec /usr/lib/doom/doomgeneric "$@" ;; esac\nexec /usr/lib/doom/doomgeneric -iwad "$wad" "$@"\n' > "$SYS/usr/bin/doom"
    chmod 755 "$SYS/usr/bin/doom"
}

# FLTK 1.3: dillo 3.2 does not support 1.4 yet
step_fltk() {
    rm -f "$SYS"/usr/lib/libfltk*
    cmk fltk -DOPTION_BUILD_SHARED_LIBS=ON -DFLTK_BUILD_TEST=OFF -DOPTION_BUILD_EXAMPLES=OFF \
        -DOPTION_USE_GL=OFF -DOPTION_USE_XFT=ON -DOPTION_USE_PANGO=OFF \
        -DOPTION_USE_SYSTEM_LIBPNG=ON -DOPTION_USE_SYSTEM_LIBJPEG=ON -DOPTION_USE_SYSTEM_ZLIB=ON
    # fltk-config prints /usr paths: a wrapper that points them into the sysroot
    cat > "$W/bin/fltk-config" <<FCEOF
#!/bin/sh
"$SYS/usr/bin/fltk-config" "\$@" | sed "s#-I/usr#-I$SYS/usr#g; s#-L/usr#-L$SYS/usr#g"
FCEOF
    chmod 755 "$W/bin/fltk-config"
}
step_dillo() {
    PATH="$W/bin:$PATH" auto dillo --enable-tls --enable-openssl --disable-mbedtls \
        --disable-gif --enable-ipv6 --disable-html-tests
}
step_mupdf() {
    s=$(unpack mupdf)
    cd "$s"
    mk() {
        make -j"$JOBS" build=release OS=Linux CC="$CC" CXX="$CXX" AR="$AR" \
            LD="$TC/bin/ld.lld -m elf_x86_64" \
            XCFLAGS="-DTOFU_CJK_EXT -DTOFU_HISTORIC -DTOFU_EMOJI -DTOFU_SIL" \
            PKG_CONFIG="$PKG_CONFIG" prefix=/usr HAVE_X11=yes HAVE_GLUT=no HAVE_CURL=no \
            HAVE_WAYLAND=no USE_SYSTEM_FREETYPE=yes USE_SYSTEM_HARFBUZZ=yes \
            USE_SYSTEM_LIBJPEG=yes USE_SYSTEM_ZLIB=yes shared=yes tesseract=no barcode=no \
            "$@"
    }
    # shared: the library (fonts included) once, not in every program
    mk apps
    o=build/shared-release
    install -m755 "$o/mupdf-x11" "$SYS/usr/bin/mupdf-x11"
    install -m755 "$o/mutool" "$SYS/usr/bin/mutool"
    rm -f "$SYS"/usr/lib/libmupdf.so*
    cp -P "$o/libmupdf.so" "$o"/libmupdf.so.[0-9]*[0-9] "$SYS/usr/lib/"
}
step_libXScrnSaver() { auto libXScrnSaver; }
step_libXpresent()   { auto libXpresent; }
step_libass()     { auto libass --disable-require-system-font-provider --disable-libunibreak; }
# headers only: libplacebo's API declares its Vulkan types even when built
# without Vulkan
step_vulkan_headers() { cmk vulkan-headers -DVULKAN_HEADERS_ENABLE_MODULE=OFF -DVULKAN_HEADERS_ENABLE_TESTS=OFF; }
step_libplacebo() {
    # its shader templates need Python's jinja2 at build time (a venv in work/)
    [ -x "$W/pyenv/bin/python" ] || { python3 -m venv "$W/pyenv" && "$W/pyenv/bin/pip" install -q jinja2; }
    PYTHONPATH="$(echo "$W"/pyenv/lib/python3*/site-packages)" mes libplacebo -Dvulkan=disabled -Dopengl=disabled -Dd3d11=disabled -Dglslang=disabled \
        -Dshaderc=disabled -Dlcms=disabled -Dlibdovi=disabled -Ddemos=false -Dtests=false \
        -Dxxhash=disabled -Dunwind=disabled
}
step_mpv() {
    mes mpv -Dlua=disabled -Djavascript=disabled -Dlibmpv=false -Dcplayer=true \
        -Dx11=enabled -Dgl=enabled -Dgl-x11=enabled -Degl=enabled -Degl-x11=enabled \
        -Dvulkan=disabled -Dwayland=disabled -Dalsa=enabled -Dpulse=disabled \
        -Dpipewire=disabled -Djack=disabled -Dvaapi=enabled -Dvaapi-x11=enabled \
        -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled \
        -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled -Dcdda=disabled \
        -Duchardet=disabled -Drubberband=disabled -Dzimg=disabled -Dlcms2=disabled \
        -Dvapoursynth=disabled -Dsdl2-audio=disabled -Dsdl2-video=disabled
}
step_fox() {
    s=$(unpack fox)
    # reswrap runs during the build: make it a static binary the host can run
    (cd "$s/utils" && "$CXX" -O2 -static -o reswrap reswrap.cpp)
    b="$W/build/fox"; rm -rf "$b"; mkdir -p "$b"
    cp "$s/utils/reswrap" "$W/bin/reswrap"
    # FOX 1.6 predates C++17 (it uses 'register')
    (cd "$b" && CXX="$CXX -std=c++14" "$s/configure" --host=$TARGET --build=$BUILD_TRIPLE --prefix=/usr \
        --disable-static --enable-shared --enable-release --with-xft --with-opengl=no \
        --disable-jpeg --disable-tiff --enable-png --enable-zlib --disable-bz2lib \
        && make -j"$JOBS" RESWRAP="$W/bin/reswrap" \
        && make DESTDIR="$SYS" install)
    cleanup_la
    cat > "$W/bin/fox-config" <<FCEOF
#!/bin/sh
"$SYS/usr/bin/fox-config" "\$@" | sed "s#-I/usr#-I$SYS/usr#g; s#-L/usr#-L$SYS/usr#g"
FCEOF
    chmod 755 "$W/bin/fox-config"
}
step_xcb_util() { auto xcb-util; }
step_xfe() {
    # configure asks the BUILD machine for pkexec and then wants polkit;
    # FreeLinX elevates with doas, so hide the host's pkexec
    mkdir -p "$W/nopkexec"
    printf '#!/bin/sh\nexit 1\n' > "$W/nopkexec/pkexec"; chmod 755 "$W/nopkexec/pkexec"
    # built inside its source tree: its icon Makefiles glob *.png in place
    s=$(unpack xfe)
    (cd "$s" && PATH="$W/nopkexec:$W/bin:$PATH" ./configure --host=$TARGET --build=$BUILD_TRIPLE \
        --prefix=/usr --sysconfdir=/etc --disable-nls --enable-release \
        ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
        && PATH="$W/bin:$PATH" make -j"$JOBS" && make DESTDIR="$SYS" install)
}

# --- H.264/AAC for FreeLinX Web: shared LGPL FFmpeg (no GPL parts) ----------
step_ffmpeg() {
    s=$(unpack ffmpeg)
    b="$W/build/ffmpeg"; rm -rf "$b"; mkdir -p "$b"
    (cd "$b" && "$s/configure" --prefix=/usr --enable-shared --disable-static \
        --enable-cross-compile --target-os=linux --arch=x86_64 --cc="$CC" --cxx="$CXX" \
        --ar="$AR" --nm="$NM" --ranlib="$RANLIB" --strip="$STRIP" --pkg-config="$PKG_CONFIG" \
        --x86asmexe=nasm --enable-pic --disable-ffplay --disable-doc --disable-debug \
        --disable-autodetect --disable-network --enable-zlib --enable-vaapi --enable-libdrm \
        && make -j"$JOBS" && make DESTDIR="$SYS" install)
}
# --- Bluetooth: bluez with libedit standing in for GNU readline -------------
# musl's wchar_t is UCS-4 but it does not predefine __STDC_ISO_10646__ (glibc
# does, in stdc-predef.h); libedit refuses to build without it.
step_libedit()  { CFLAGS="-O2 -D__STDC_ISO_10646__=201103L" auto libedit; }
step_bluez() {
    # bluetoothctl includes <readline/readline.h>; libedit ships a compatible
    # API as <editline/readline.h>.
    mkdir -p "$SYS/usr/include/readline"
    cat > "$SYS/usr/include/readline/readline.h" <<'RLEOF'
#ifndef FLX_READLINE_COMPAT_H
#define FLX_READLINE_COMPAT_H
/* GNU readline API subset over libedit (BSD) for bluetoothctl. */
#include <stdio.h>
#include <editline/readline.h>
/* not in libedit: erase the prompt line / forget the drawn state */
static inline int rl_clear_visible_line(void)
{
	fputs("\r\033[K", rl_outstream ? rl_outstream : stdout);
	fflush(rl_outstream ? rl_outstream : stdout);
	return 0;
}
static inline void rl_reset_line_state(void) { rl_on_new_line(); }
#endif
RLEOF
    printf '#include <editline/readline.h>\n' > "$SYS/usr/include/readline/history.h"
    # its Makefiles hard-code -lreadline: resolve that to libedit at link time
    # (the binaries record libedit's soname).
    ln -sf libedit.so "$SYS/usr/lib/libreadline.so"
    auto bluez --disable-systemd --disable-manpages --disable-cups --disable-obex \
        --disable-mesh --disable-midi --disable-udev --disable-hid2hci --disable-datafiles \
        --enable-client --enable-tools --enable-library --disable-test \
        --with-dbusconfdir=/etc --with-dbussystembusdir=/usr/share/dbus-1/system-services \
        READLINE_CFLAGS="-I$SYS/usr/include" READLINE_LIBS="-ledit -lcurses -lterminfo"
}
# --- hostapd (access point; lets flxnetmgr's WiFi path be tested with hwsim)
step_hostapd() {
    s=$(unpack hostapd)
    cd "$s/hostapd"
    cp defconfig .config
    { echo 'CONFIG_DRIVER_NL80211=y'; echo 'CONFIG_LIBNL32=y'; echo 'CONFIG_TLS=openssl';
      echo 'CONFIG_SAE=y'; echo 'CONFIG_IEEE80211W=y'; } >> .config
    make -j"$JOBS" CC="$CC" PKG_CONFIG="$PKG_CONFIG" EXTRA_CFLAGS="-I$SYS/usr/include/libnl3" BINDIR=/sbin
    make DESTDIR="$SYS" BINDIR=/sbin install
}

STEPS_USER="tzdata flxapps toybox openssl sqlite libnl wpa_supplicant flxnet xpkg netbsd_curses musl_fts nnn libXaw xcalc imlib2 tint2 alsa_utils libXxf86vm llvm18 libelf libva mesa_clc_host mesa mesa_demos libva_utils gmmlib media_driver intel_vaapi ffmpeg libedit bluez hostapd ca_certificates flx_x11_tools openbox xbitmaps xsetroot xrandr setxkbmap xinit xeyes xclock xmag xclip dwm dmenu st slstatus nsxiv feh libptytty rxvt_unicode doomgeneric libconfuse yajl i3status fltk dillo mupdf libXScrnSaver libXpresent libass vulkan_headers libplacebo mpv fox xcb_util xfe"

STEPS="musl kheaders cxxrt zlib libffi pcre2 expat libpng libjpeg freetype fontconfig
pixman libmd util_macros xorgproto xcb_proto libXau libXdmcp xtrans libxcb libX11
libXext libXrender libXfixes libXi libXrandr libXcursor libXcomposite libXdamage
libXinerama libXtst libICE libSM libXt libXmu libXft libXpm libxkbfile libfontenc
libXfont2 libxshmfence libpciaccess libdrm libxcvt mtdev libevdev libudev_zero
xorg_server xf86_video_fbdev xf86_input_evdev xkbcomp libinput xf86_input_libinput glib glib_tools fribidi harfbuzz cairo
pango gdk_pixbuf pixbuf_tools libxml2 dbus at_spi2_core libepoxy gtk3 alsa_lib $STEPS_USER"

run_step() {
    st="$W/stamps/$1"
    echo ">>> $1"
    # Not inside an if/&&: set -e must stay live in the step's subshell, or a
    # failed configure would fall through and the step be stamped "ok".
    set +e
    ( set -e; "step_$1" ) > "$W/logs/$1.log" 2>&1
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        touch "$st"
        echo "    ok"
    else
        echo "    FAILED - see $W/logs/$1.log" >&2
        tail -25 "$W/logs/$1.log" >&2
        exit 1
    fi
}

if [ $# -gt 0 ]; then
    for s in "$@"; do run_step "$s"; done
else
    for s in $STEPS; do
        [ -f "$W/stamps/$s" ] && continue
        run_step "$s"
    done
fi
echo "build-stack: done ($SYS)"

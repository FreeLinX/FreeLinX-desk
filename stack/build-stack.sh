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
chmod +x "$W/bin/flx-cc" "$W/bin/flx-c++" "$W/bin/pkg-config" "$W/bin/musl-run"

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
}

mes() { # name [meson args...]
    n="$1"; shift
    s=$(unpack "$n")
    b="$W/build/$n"; rm -rf "$b"
    "$MESON" setup "$b" "$s" --cross-file "$W/cross.ini" --prefix=/usr \
        --sysconfdir=/etc --localstatedir=/var --libdir=lib \
        --buildtype=release --default-library=shared --wrap-mode=nofallback "$@"
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
    ksrc="${KERNEL_SRC:-$TOP/../kernel/linux-6.6.21}"
    [ -d "$ksrc" ] || { echo "kernel source not found: $ksrc" >&2; exit 1; }
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
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=OFF
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
    mes libdrm -Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled \
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
        -Dxquartz=false -Dglamor=false -Dglx=false -Ddri1=false -Ddri2=false -Ddri3=false \
        -Dudev=false -Dudev_kms=false -Dsystemd_logind=false -Dsuid_wrapper=false \
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
step_xf86_input_libinput() { auto xf86-input-libinput; }

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
step_libepoxy()    { mes libepoxy -Degl=no -Dglx=yes -Dx11=true -Dtests=false -Ddocs=false; }
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
step_sqlite()  { auto sqlite --disable-readline --disable-editline; }
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
step_ncurses() {
    auto ncurses --with-shared --without-normal --without-debug --without-ada \
        --enable-widec --without-cxx-binding --without-manpages --without-tests \
        --with-pkg-config-libdir=/usr/lib/pkgconfig --enable-pc-files \
        --with-termlib --with-default-terminfo-dir=/usr/share/terminfo \
        --disable-stripping
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
step_libXaw()  { auto libXaw --disable-specs --disable-xaw6; }
step_xcalc()   { auto xcalc; }

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
}

# toybox (0BSD): only the process/system tools NetBSD's userland cannot
# provide on Linux (NetBSD ps/top need kvm and sys/lwp.h).
TOYBOX_APPLETS="ps top free uptime pgrep pkill pidof w getty login"
step_toybox() {
    s=$(unpack toybox)
    cd "$s"
    : > flx-mini.config
    for t in $TOYBOX_APPLETS; do
        echo "CONFIG_$(echo "$t" | tr a-z A-Z)=y" >> flx-mini.config
    done
    make allnoconfig KCONFIG_ALLCONFIG=flx-mini.config >/dev/null
    make toybox CC="$CC" CFLAGS="-O2" LDFLAGS="" HOSTCC=cc
    mkdir -p "$SYS/usr/bin"
    install -m755 toybox "$SYS/usr/bin/toybox"
    for t in $TOYBOX_APPLETS; do ln -sf toybox "$SYS/usr/bin/$t"; done
}

STEPS_USER="tzdata flxapps toybox openssl sqlite libnl wpa_supplicant flxnet xpkg ncurses musl_fts nnn libXaw xcalc imlib2 tint2"

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

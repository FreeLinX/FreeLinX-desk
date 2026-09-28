#!/bin/sh
# FreeLinX Desktop - Firefox ESR, cross compiled for x86_64-linux-musl
#
# Needs the GUI stack first (stack/build-stack.sh: gtk3 + X11 + alsa-lib in
# $STACK_WORK/sysroot).  Uses the FreeLinX LLVM toolchain for the target and
# the toolchain clang (host triple) for host tools.  Musl fixes come from
# Alpine's firefox package (stack/patches/firefox/alpine), which applies
# cleanly to 153 ESR.
#
# Host requirements: rustup with the x86_64-unknown-linux-musl target and
# rust-src, cbindgen, nodejs, nasm, python3, and a libclang the host can
# dlopen for bindgen (LIBCLANG_DIR; the pip "libclang" wheel works).
#
# Output: $STACK_WORK/firefox-dest/usr/lib/firefox (staged install)
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
SYS="$W/sysroot"
VER="${FIREFOX_VERSION:-153.3.0esr}"
SRCNAME="firefox-${VER%esr}"
DIST="${STACK_DIST:-$TOP/ports/dist}"
TARBALL="$DIST/firefox-$VER.source.tar.xz"
SHA256="69f1335e78d2a340fc13fcf265c0a72bdce2df8774c9d4d49ee77d1726236df5"
SRC="$W/src/firefox/$SRCNAME"
OBJ="$W/build/firefox"
DEST="$W/firefox-dest"
JOBS="${JOBS:-6}"
LIBCLANG_DIR="${LIBCLANG_DIR:-$W/host-libclang/libclang-18.1.1.data/platlib/clang/native}"

[ -f "$SYS/usr/lib/pkgconfig/gtk+-x11-3.0.pc" ] || { echo "build the GUI stack first (gtk3 missing)" >&2; exit 1; }

if [ ! -f "$TARBALL" ]; then
    curl -fL -o "$TARBALL.part" "https://archive.mozilla.org/pub/firefox/releases/$VER/source/firefox-$VER.source.tar.xz"
    mv "$TARBALL.part" "$TARBALL"
fi
echo "$SHA256  $TARBALL" | sha256sum -c -

if [ ! -f "$SRC/.flx-prepared" ]; then
    rm -rf "$W/src/firefox"; mkdir -p "$W/src/firefox"
    tar -xf "$TARBALL" -C "$W/src/firefox"
    for p in abseil-cpp fix-fortify-system-wrappers fix-rust-target glean-stub lfs64 \
             musl-no-linux-prctl rust-lto-thin sandbox-sched_setscheduler time64 wasip1; do
        patch -d "$SRC" -p1 -s < "$HERE/patches/firefox/alpine/$p.patch"
    done
    for p in "$HERE"/patches/firefox/*.patch; do
        [ -f "$p" ] && patch -d "$SRC" -p1 -s < "$p"
    done
    cp "$HERE/patches/firefox/alpine/stab.h" "$SRC/toolkit/crashreporter/google-breakpad/src/"
    # Patched vendored crates: drop their file checksums so cargo accepts them.
    for c in audio_thread_priority cc zeitstempel wgpu-hal alsa; do
        f="$SRC/third_party/rust/$c/.cargo-checksum.json"
        [ -f "$f" ] && python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));d['files']={};json.dump(d,open(p,'w'))" "$f"
    done
    touch "$SRC/.flx-prepared"
fi

TFLAGS="--sysroot=$SYS -O2"
cat > "$W/mozconfig" <<EOF
ac_add_options --enable-application=browser
ac_add_options --target=x86_64-unknown-linux-musl
ac_add_options --prefix=/usr
ac_add_options --disable-bootstrap
ac_add_options --enable-default-toolkit=cairo-gtk3-x11-only
ac_add_options --enable-audio-backends=alsa
ac_add_options --disable-dbus
ac_add_options --disable-necko-wifi
ac_add_options --disable-jemalloc
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-tests
ac_add_options --disable-debug
ac_add_options --disable-debug-symbols
ac_add_options --enable-optimize=-O2
ac_add_options --enable-release
ac_add_options --enable-strip
ac_add_options --enable-linker=lld
ac_add_options --without-wasm-sandboxed-libraries
ac_add_options --with-libclang-path=$LIBCLANG_DIR
ac_add_options --with-distribution-id=org.freelinx
mk_add_options MOZ_OBJDIR=$OBJ
mk_add_options MOZ_PARALLEL_BUILD=$JOBS
EOF

export MOZCONFIG="$W/mozconfig"
export MOZBUILD_STATE_PATH="$W/mozbuild"
export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none
export MOZ_NOSPAM=1
export SHELL=/bin/sh
# Target compilers: the FreeLinX toolchain against the stack sysroot.
export CC="$TC/bin/clang --target=x86_64-linux-musl"
export CXX="$TC/bin/clang++ --target=x86_64-linux-musl -stdlib=libc++"
export CFLAGS="$TFLAGS"
export CXXFLAGS="$TFLAGS"
export LDFLAGS="--sysroot=$SYS -rtlib=compiler-rt -unwindlib=libunwind -Wl,--undefined-version"
# Host tools (build-time only, never shipped).
export HOST_CC="$TC/bin/clang"
export HOST_CXX="$TC/bin/clang++"
export HOST_CFLAGS="-O2" HOST_CXXFLAGS="-O2" HOST_LDFLAGS=""
export AR="$TC/bin/llvm-ar" NM="$TC/bin/llvm-nm" RANLIB="$TC/bin/llvm-ranlib"
export STRIP="$TC/bin/llvm-strip" OBJCOPY="$TC/bin/llvm-objcopy"
export PKG_CONFIG="$W/bin/pkg-config"
export RUST_TARGET=x86_64-unknown-linux-musl
# Link Rust code against our musl/crt/libunwind, not rustup's self-contained
# (GCC-built) copies.
export RUSTFLAGS="-C link-self-contained=no -C target-feature=-crt-static"
export PATH="$HOME/.cargo/bin:$TC/bin:$PATH"

cd "$SRC"
./mach build
rm -rf "$DEST"
DESTDIR="$DEST" ./mach install
echo "build-firefox: staged in $DEST"

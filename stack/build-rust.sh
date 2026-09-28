#!/bin/sh
# FreeLinX Desktop - Rust programs (greetd, tuigreet) + Linux-PAM
#
# rustup's prebuilt x86_64-unknown-linux-musl std carries GCC-compiled
# objects (self-contained crt*.o/libc.a/libunwind.a and the C half of
# compiler_builtins).  So std is rebuilt from rust-src (-Zbuild-std, pure
# Rust compiler_builtins) and linked with the FreeLinX clang against the stack
# sysroot's musl and LLVM libunwind (link-self-contained=no).
#
# Needs: stack/build-stack.sh done (sysroot + wrappers), rustup with rust-src.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
TC="${FREELINX_TOOLCHAIN_DIR:-$(cd "$TOP/../toolchain" && pwd)}"
W="${STACK_WORK:-$HERE/work}"
SYS="$W/sysroot"
DIST="${STACK_DIST:-$TOP/ports/dist}"
JOBS="${JOBS:-$(nproc)}"
MESON="${MESON:-$TOP/.venv/bin/meson}"
[ -x "$MESON" ] || MESON=meson
[ -x "$W/bin/flx-cc" ] || { echo "run stack/build-stack.sh first" >&2; exit 1; }

export PATH="$W/bin:$HOME/.cargo/bin:$PATH"
export PKG_CONFIG="$W/bin/pkg-config"

fetch() { # url sha256|- localname
    f="$DIST/$3"
    [ -f "$f" ] || curl -fL --retry 3 -o "$f" "$1"
    if [ "$2" != "-" ]; then echo "$2  $f" | sha256sum -c - >/dev/null; fi
    echo "$f"
}
unpack() { # url sha name -> dir
    a=$(fetch "$1" "$2" "$3.tar.gz")
    rm -rf "$W/src/$3"; mkdir -p "$W/src/$3"
    tar -xf "$a" -C "$W/src/$3"
    find "$W/src/$3" -mindepth 1 -maxdepth 1 -type d | head -1
}

# --- Linux-PAM (shared, modules in /lib/security) ----------------------------
if [ ! -f "$SYS/usr/lib/libpam.so" ]; then
    a="$DIST/Linux-PAM-1.7.0.tar.xz"
    [ -f "$a" ] || curl -fL -o "$a" https://github.com/linux-pam/linux-pam/releases/download/v1.7.0/Linux-PAM-1.7.0.tar.xz
    rm -rf "$W/src/linux-pam"; mkdir -p "$W/src/linux-pam"
    tar -xf "$a" -C "$W/src/linux-pam"
    s="$W/src/linux-pam/Linux-PAM-1.7.0"
    rm -rf "$W/build/linux-pam"
    "$MESON" setup "$W/build/linux-pam" "$s" --cross-file "$W/cross.ini" --prefix=/usr \
        --sysconfdir=/etc --libdir=lib --buildtype=release \
        -Ddocs=disabled -Dexamples=false -Dxtests=false -Daudit=disabled \
        -Deconf=disabled -Dselinux=disabled -Dnis=disabled -Dlogind=disabled \
        -Dopenssl=disabled -Di18n=enabled -Dpam_userdb=disabled \
        -Dsecuredir=/lib/security
    "$MESON" compile -C "$W/build/linux-pam" -j "$JOBS"
    DESTDIR="$SYS" "$MESON" install -C "$W/build/linux-pam" --no-rebuild
fi

# --- cargo against the stack sysroot ----------------------------------------
RT=x86_64-unknown-linux-musl
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="$W/bin/flx-cc"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-C link-self-contained=no -C target-feature=-crt-static -L $SYS/usr/lib"
export CC_x86_64_unknown_linux_musl="$W/bin/flx-cc"
export AR_x86_64_unknown_linux_musl="$TC/bin/llvm-ar"
export PKG_CONFIG_ALLOW_CROSS=1
export RUSTC_BOOTSTRAP=1

cargo_build() { # srcdir outdir-bin...
    d="$1"; shift
    (cd "$d" && cargo build --release --locked --target $RT \
        -Zbuild-std=std,panic_abort -Zbuild-std-features=llvm-libunwind -j "$JOBS")
    mkdir -p "$SYS/usr/bin"
    for b in "$@"; do
        install -m755 "$d/target/$RT/release/$b" "$SYS/usr/bin/$b"
        "$TC/bin/llvm-strip" "$SYS/usr/bin/$b"
    done
}

g=$(unpack https://git.sr.ht/~kennylevinsen/greetd/archive/0.10.3.tar.gz - greetd-0.10.3)
cargo_build "$g" greetd agreety
t=$(unpack https://github.com/apognu/tuigreet/archive/refs/tags/0.9.1.tar.gz - tuigreet-0.9.1)
cargo_build "$t" tuigreet
echo "build-rust: greetd, agreety, tuigreet installed into $SYS/usr/bin"

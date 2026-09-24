#!/bin/sh
# FreeLinX - compile desktop apps statically against musl toolchain
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLCHAIN="${FREELINX_TOOLCHAIN_DIR:-${SCRIPT_DIR}/../toolchain}"
CLANG="${TOOLCHAIN}/bin/clang"
STRIP="${TOOLCHAIN}/bin/llvm-strip"
SYSROOT="${TOOLCHAIN}/x86_64-linux-musl"

if [ ! -x "$CLANG" ]; then
    echo "Notice: FreeLinX toolchain clang not found at $CLANG; skipping app rebuild."
    exit 0
fi

# Static X11/cairo stack lives inside the toolchain sysroot.
INC="-I${SYSROOT}/include -I${SYSROOT}/include/freetype2"
CAIRO_LIBS="-L${SYSROOT}/lib -lcairo -lpixman-1 -lfontconfig -lfreetype \
-lXrender -lXext -lX11 -lX11-xcb -lxcb-render -lxcb-shm -lxcb -lXau -lXdmcp \
-lexpat -lpng -lz -lm"

echo "Building st (uxterm)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $INC \
  -I"${SCRIPT_DIR}/st-src" \
  -DVERSION=\"0.9.3\" -D_XOPEN_SOURCE=600 \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/st" \
  "${SCRIPT_DIR}/st-src/st.c" \
  "${SCRIPT_DIR}/st-src/x.c" \
  -L"${SYSROOT}/lib" -lXft -lfontconfig -lfreetype -lXrender -lXext \
  -lX11 -lxcb -lXau -lXdmcp -lexpat -lpng -lz -lm
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/st"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/st" "${FREELINX_SRC_DIR:-${SCRIPT_DIR}/../src}/rootfs/usr/bin/st" 2>/dev/null || true

echo "Building xmag (Screen Magnifier)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $INC \
  $CAIRO_LIBS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" \
  "${SCRIPT_DIR}/xmag.c"
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" "${FREELINX_SRC_DIR:-${SCRIPT_DIR}/../src}/rootfs/usr/bin/xmag" 2>/dev/null || true

echo "Building xclock (Retro Plan 9 Clock)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $INC \
  $CAIRO_LIBS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock" \
  "${SCRIPT_DIR}/xclock.c"
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock" "${FREELINX_SRC_DIR:-${SCRIPT_DIR}/../src}/rootfs/usr/bin/xclock" 2>/dev/null || true

echo "Building flxinstall-gui (GUI installer)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $INC \
  $CAIRO_LIBS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flxinstall-gui" \
  "${SCRIPT_DIR}/flxinstall-gui.c"
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flxinstall-gui"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flxinstall-gui" "${FREELINX_SRC_DIR:-${SCRIPT_DIR}/../src}/rootfs/usr/bin/flxinstall-gui" 2>/dev/null || true

echo "All desktop applications built successfully."
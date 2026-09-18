#!/bin/sh
# FreeLinX - compile desktop apps statically against musl toolchain
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLCHAIN=/home/devuan/FreeLinX/toolchain
CLANG="${TOOLCHAIN}/bin/clang"
STRIP="${TOOLCHAIN}/bin/llvm-strip"
SYSROOT="${TOOLCHAIN}/x86_64-linux-musl"
DEPS="${SCRIPT_DIR}/ports/build/deps"

if [ ! -x "$CLANG" ]; then
    echo "Notice: FreeLinX toolchain clang not found at $CLANG; skipping app rebuild."
    exit 0
fi

CAIRO_INCS="-I$DEPS/cairo-1.18.4/include -I$DEPS/x11/include -I$DEPS/fontconfig/include -I$DEPS/freetype/include/freetype2 -I$DEPS/pixman/include/pixman-1"
CAIRO_LIBS="$DEPS/cairo-1.18.4/lib/libcairo.a $DEPS/pixman/lib/libpixman-1.a $DEPS/fontconfig/lib/libfontconfig.a $DEPS/freetype/lib/libfreetype.a $DEPS/x11/lib/libXrender.a $DEPS/x11/lib/libX11.a $DEPS/x11/lib/libX11-xcb.a $DEPS/x11/lib/libxcb-render.a $DEPS/x11/lib/libxcb-shm.a $DEPS/x11/lib/libxcb.a $DEPS/x11/lib/libXau.a $DEPS/x11/lib/libXdmcp.a $DEPS/expat/lib/libexpat.a $DEPS/libpng/lib/libpng.a $DEPS/zlib/lib/libz.a -lm"

echo "Building st (uxterm)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -I"$DEPS/x11/include" \
  -I"$DEPS/fontconfig/include" \
  -I"$DEPS/freetype/include/freetype2" \
  -I"${SCRIPT_DIR}/st-src" \
  -DVERSION=\"0.9.3\" -D_XOPEN_SOURCE=600 \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/st" \
  "${SCRIPT_DIR}/st-src/st.c" \
  "${SCRIPT_DIR}/st-src/x.c" \
  "$DEPS/x11/lib/libXft.a" \
  "$DEPS/fontconfig/lib/libfontconfig.a" \
  "$DEPS/freetype/lib/libfreetype.a" \
  "$DEPS/x11/lib/libXrender.a" \
  "$DEPS/x11/lib/libX11.a" \
  "$DEPS/x11/lib/libxcb.a" \
  "$DEPS/x11/lib/libXau.a" \
  "$DEPS/x11/lib/libXdmcp.a" \
  "$DEPS/expat/lib/libexpat.a" \
  "$DEPS/libpng/lib/libpng.a" \
  "$DEPS/zlib/lib/libz.a" \
  -lm
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/st"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/st" /home/devuan/FreeLinX/src/rootfs/usr/bin/st 2>/dev/null || true

echo "Building xmag (Screen Magnifier)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" \
  "${SCRIPT_DIR}/xmag.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" /home/devuan/FreeLinX/src/rootfs/usr/bin/xmag 2>/dev/null || true


echo "Building xclock (Retro Plan 9 Clock)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock" \
  "${SCRIPT_DIR}/xclock.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/xclock" /home/devuan/FreeLinX/src/rootfs/usr/bin/xclock 2>/dev/null || true

echo "All desktop applications built successfully."

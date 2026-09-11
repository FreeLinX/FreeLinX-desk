#!/bin/sh
# FreeLinX - compile fview and st (uxterm) statically against musl toolchain
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLCHAIN=/home/devuan/FreeLinX/toolchain
CLANG="${TOOLCHAIN}/bin/clang"
SYSROOT="${TOOLCHAIN}/x86_64-linux-musl"
DEPS="${SCRIPT_DIR}/ports/build/deps"

if [ ! -x "$CLANG" ]; then
    echo "Notice: FreeLinX toolchain clang not found at $CLANG; skipping app rebuild."
    exit 0
fi

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

echo "Building fview (File Manager)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -I"$DEPS/cairo-1.18.4/include" \
  -I"$DEPS/x11/include" \
  -I"$DEPS/fontconfig/include" \
  -I"$DEPS/freetype/include/freetype2" \
  -I"$DEPS/pixman/include/pixman-1" \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/fview" \
  "${SCRIPT_DIR}/fview.c" \
  "$DEPS/cairo-1.18.4/lib/libcairo.a" \
  "$DEPS/pixman/lib/libpixman-1.a" \
  "$DEPS/fontconfig/lib/libfontconfig.a" \
  "$DEPS/freetype/lib/libfreetype.a" \
  "$DEPS/x11/lib/libXrender.a" \
  "$DEPS/x11/lib/libX11.a" \
  "$DEPS/x11/lib/libX11-xcb.a" \
  "$DEPS/x11/lib/libxcb-render.a" \
  "$DEPS/x11/lib/libxcb-shm.a" \
  "$DEPS/x11/lib/libxcb.a" \
  "$DEPS/x11/lib/libXau.a" \
  "$DEPS/x11/lib/libXdmcp.a" \
  "$DEPS/expat/lib/libexpat.a" \
  "$DEPS/libpng/lib/libpng.a" \
  "$DEPS/zlib/lib/libz.a" \
  -lm

echo "Applications built successfully."

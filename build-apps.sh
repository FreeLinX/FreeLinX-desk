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

echo "Building flx-fm (File Manager)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -I"$DEPS/cairo-1.18.4/include" \
  -I"$DEPS/x11/include" \
  -I"$DEPS/fontconfig/include" \
  -I"$DEPS/freetype/include/freetype2" \
  -I"$DEPS/pixman/include/pixman-1" \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm" \
  "${SCRIPT_DIR}/flx-fm.c" \
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
"${TOOLCHAIN}/bin/llvm-strip" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm"
ln -sf flx-fm "${SCRIPT_DIR}/src/rootfs/usr/bin/fview"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-fm 2>/dev/null || true
ln -sf flx-fm /home/devuan/FreeLinX/src/rootfs/usr/bin/fview 2>/dev/null || true

echo "Building glxgears (OpenGL 3D Demo & Benchmark)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O3 -static \
  -I"${SCRIPT_DIR}/glxgears-src/include" \
  -I"${SCRIPT_DIR}/glxgears-src/src" \
  -I"$DEPS/x11/include" \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/glxgears" \
  "${SCRIPT_DIR}/glxgears-src/src/api.c" \
  "${SCRIPT_DIR}/glxgears-src/src/list.c" \
  "${SCRIPT_DIR}/glxgears-src/src/vertex.c" \
  "${SCRIPT_DIR}/glxgears-src/src/init.c" \
  "${SCRIPT_DIR}/glxgears-src/src/matrix.c" \
  "${SCRIPT_DIR}/glxgears-src/src/texture.c" \
  "${SCRIPT_DIR}/glxgears-src/src/misc.c" \
  "${SCRIPT_DIR}/glxgears-src/src/clear.c" \
  "${SCRIPT_DIR}/glxgears-src/src/light.c" \
  "${SCRIPT_DIR}/glxgears-src/src/clip.c" \
  "${SCRIPT_DIR}/glxgears-src/src/select.c" \
  "${SCRIPT_DIR}/glxgears-src/src/get.c" \
  "${SCRIPT_DIR}/glxgears-src/src/error.c" \
  "${SCRIPT_DIR}/glxgears-src/src/zbuffer.c" \
  "${SCRIPT_DIR}/glxgears-src/src/zline.c" \
  "${SCRIPT_DIR}/glxgears-src/src/ztriangle.c" \
  "${SCRIPT_DIR}/glxgears-src/src/zmath.c" \
  "${SCRIPT_DIR}/glxgears-src/src/image_util.c" \
  "${SCRIPT_DIR}/glxgears-src/src/msghandling.c" \
  "${SCRIPT_DIR}/glxgears-src/src/arrays.c" \
  "${SCRIPT_DIR}/glxgears-src/src/specbuf.c" \
  "${SCRIPT_DIR}/glxgears-src/src/memory.c" \
  "${SCRIPT_DIR}/glxgears-src/src/zdither.c" \
  "${SCRIPT_DIR}/glxgears-src/src/glx.c" \
  "${SCRIPT_DIR}/glxgears-src/glxgears.c" \
  "$DEPS/x11/lib/libXext.a" \
  "$DEPS/x11/lib/libX11.a" \
  "$DEPS/x11/lib/libxcb.a" \
  "$DEPS/x11/lib/libXau.a" \
  "$DEPS/x11/lib/libXdmcp.a" \
  -lm
"${TOOLCHAIN}/bin/llvm-strip" "${SCRIPT_DIR}/src/rootfs/usr/bin/glxgears"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/glxgears" /home/devuan/FreeLinX/src/rootfs/usr/bin/glxgears 2>/dev/null || true

echo "Building xmag (Screen Magnifier)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -I"$DEPS/cairo-1.18.4/include" \
  -I"$DEPS/x11/include" \
  -I"$DEPS/fontconfig/include" \
  -I"$DEPS/freetype/include/freetype2" \
  -I"$DEPS/pixman/include/pixman-1" \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" \
  "${SCRIPT_DIR}/xmag.c" \
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
"${TOOLCHAIN}/bin/llvm-strip" "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/xmag" /home/devuan/FreeLinX/src/rootfs/usr/bin/xmag 2>/dev/null || true

echo "Applications built successfully."

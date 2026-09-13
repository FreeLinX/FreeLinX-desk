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

echo "Building flx-fm (File Manager)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm" \
  "${SCRIPT_DIR}/flx-fm.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm"
ln -sf flx-fm "${SCRIPT_DIR}/src/rootfs/usr/bin/fview"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fm" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-fm 2>/dev/null || true
ln -sf flx-fm /home/devuan/FreeLinX/src/rootfs/usr/bin/fview 2>/dev/null || true

echo "Building flx-bg (Wallpaper Setter)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-bg" \
  "${SCRIPT_DIR}/flx-bg.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-bg"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-bg" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-bg 2>/dev/null || true

echo "Building flx-panel (Desktop Panel & Taskbar)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-panel" \
  "${SCRIPT_DIR}/flx-panel.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-panel"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-panel" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-panel 2>/dev/null || true

echo "Building flx-shot (Screenshot Tool)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-shot" \
  "${SCRIPT_DIR}/flx-shot.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-shot"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-shot" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-shot 2>/dev/null || true

echo "Building flx-pad (Text Editor)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-pad" \
  "${SCRIPT_DIR}/flx-pad.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-pad"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-pad" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-pad 2>/dev/null || true

echo "Building flx-view (Image Viewer)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  $CAIRO_INCS \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-view" \
  "${SCRIPT_DIR}/flx-view.c" \
  $CAIRO_LIBS
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-view"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-view" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-view 2>/dev/null || true

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
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/glxgears"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/glxgears" /home/devuan/FreeLinX/src/rootfs/usr/bin/glxgears 2>/dev/null || true

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

echo "Building unzip (Archive Extractor)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -I/home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/libarchive \
  -I/home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/libarchive_fe \
  -I/home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/unzip \
  -DHAVE_CONFIG_H \
  -I/home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9 \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/unzip/bsdunzip.c \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/unzip/cmdline.c \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/libarchive_fe/lafe_err.c \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/libarchive_fe/lafe_fnmatch.c \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/libarchive_fe/passphrase.c \
  /home/devuan/FreeLinX/ports/build/work/libarchive/libarchive-3.8.9/.libs/libarchive.a \
  "$DEPS/zlib/lib/libz.a" \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/unzip"
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/unzip"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/unzip" /home/devuan/FreeLinX/src/rootfs/usr/bin/unzip 2>/dev/null || true

echo "Building flx-fs and mkfs.flxfs (Custom Filesystem Tools)..."
"$CLANG" \
  --target=x86_64-linux-musl \
  --sysroot="$SYSROOT" \
  -fuse-ld=lld --rtlib=compiler-rt -O2 -static \
  -o "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fs" \
  "${SCRIPT_DIR}/flx-fs.c"
"$STRIP" "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fs"
ln -sf flx-fs "${SCRIPT_DIR}/src/rootfs/usr/bin/mkfs.flxfs"
cp -f "${SCRIPT_DIR}/src/rootfs/usr/bin/flx-fs" /home/devuan/FreeLinX/src/rootfs/usr/bin/flx-fs 2>/dev/null || true
ln -sf flx-fs /home/devuan/FreeLinX/src/rootfs/usr/bin/mkfs.flxfs 2>/dev/null || true

echo "All desktop applications built successfully."

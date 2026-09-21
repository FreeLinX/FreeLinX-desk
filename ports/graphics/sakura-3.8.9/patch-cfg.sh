#!/bin/sh
# FreeLinX/ports - graphics/sakura-3.8.9 : source patches (run inside SRC_TREE).
# Idempotent: each rule matches the line it produced last time as well as the
# pristine upstream text. X11 backend is unavailable in the FreeLinX Wayland
# guest and gdkx.h is not installed by our gtk build, so X11 is dropped and
# the unconditional gdkx.h include removed (X11 paths are #ifdef'd on
# GDK_WINDOWING_X11 anyway). pcre2 include/link added; po dir skipped; libc++
# (vte is C++) and the full static closure linked under --start-group.
set -e

# This script always lives at <repo>/ports/graphics/sakura-3.8.9/, so
# everything else derives from its own location (never absolute).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS="$SCRIPT_DIR/../../build/deps"

sed -i 's/^PROJECT (sakura)$/PROJECT (sakura LANGUAGES C)/' CMakeLists.txt
sed -i '/^ADD_SUBDIRECTORY (po)$/d' CMakeLists.txt
sed -i 's/pkg_check_modules (X11 REQUIRED x11)/pkg_check_modules (X11 x11)/' CMakeLists.txt
sed -i '/^IF (NOT X11_FOUND)$/,/^ENDIF (NOT X11_FOUND)$/d' CMakeLists.txt
sed -i 's#^INCLUDE_DIRECTORIES .*#INCLUDE_DIRECTORIES (. ${GTK_INCLUDE_DIRS} ${VTE_INCLUDE_DIRS} '"$DEPS"'/pcre2-10.48/include)#' CMakeLists.txt
sed -i 's#^LINK_LIBRARIES .*#LINK_LIBRARIES (-Wl,--start-group ${GTK_LIBRARIES} ${VTE_LIBRARIES} ${X11_LIBRARIES} gdk-3 atk-1.0 cairo cairo-gobject dl epoxy expat ffi fontconfig freetype fribidi gdk_pixbuf-2.0 gio-2.0 glib-2.0 gmodule-2.0 gobject-2.0 gtk-3 harfbuzz vte-2.91 pango-1.0 pangocairo-1.0 pangoft2-1.0 pcre2-8 pixman-1 png16 wayland-client wayland-cursor wayland-egl xkbcommon z lz4 m c++ c++abi unwind -Wl,--end-group)#; s#^LINK_DIRECTORIES .*#LINK_DIRECTORIES (${GTK_LIBRARY_DIRS} ${VTE_LIBRARY_DIRS} ${X11_LIBRARY_DIRS} '"$DEPS"'/wayland/lib '"$DEPS"'/libxkbcommon/lib)#' CMakeLists.txt
sed -i '/#include <gdk\/gdkx.h>/d' src/sakura.c
cp "$SCRIPT_DIR/flx_cxa_thread_atexit.c" src/flx_cxa_thread_atexit.c
sed -i 's#^ADD_EXECUTABLE (sakura src/sakura.c).*#ADD_EXECUTABLE (sakura src/sakura.c src/flx_cxa_thread_atexit.c)#' CMakeLists.txt
# FreeLinX/ports - graphics/imlib2-1.12.7 : imlib2 (image handling library).
#
# Base for feh and scrot.  Upstream ships image codecs as dlopen'd .so loader
# modules, which is impossible in a fully-static musl build.  FreeLinX patches
# src/lib/loaders.c to register the codecs statically (IMLIB2_STATIC_LOADERS):
# each loader_*.c is compiled with -Dloader=flx_loader_<name>, archived INTO
# libImlib2.a alongside ldrs_util.o/decompress_load.o, and the patched
# dispatcher hands those out instead of dlopen()ing from the filesystem.
# Loaders built: PNG(+save), ZLIB(.gz), and the zero-dependency set
# (ANI ARGB BMP FF ICO LBM PNM QOI TGA XBM XPM).  JPEG/GIF/TIFF/WEBP
# (libjpeg-turbo/giflib/tiff/webp) are skipped for now.
NAME:=imlib2-1.12.7
VERSION:=1.12.7
CATEGORY:=graphics
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11
DEPENDENCIES:=
BUILD_DEPENDENCIES:=libpng, zlib, freetype, x11 stack (libX11, libXext)

IMLIB_PREFIX=$(FREELINX_BUILD_DIR)/deps/imlib2
FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
OBJ_DIR=$(FREELINX_BUILD_DIR)/obj/$(NAME)
PROJECT_BIN=$(IMLIB_PREFIX)/lib/libImlib2.a
BUILD_BIN=$(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.  Static-loader
# registration and the dep include/link paths ride on the exported CFLAGS/
# LDFLAGS.
FLX_PROJECT_LIBS?=
FLX_PROJECT_CFLAGS=-O2 -DIMLIB2_STATIC_LOADERS
FLX_PROJECT_CPPFLAGS=-I$(FLX_PREFIX)/include -I$(DEPS_PNG_INCLUDE) -I$(DEPS_ZLIB_INCLUDE) -I$(DEPS_FT_INCLUDE)
FLX_PROJECT_LDFLAGS=-L$(FLX_PREFIX)/lib -L$(DEPS_PNG_LIB) -L$(DEPS_ZLIB_LIB) -L$(DEPS_FT_LIB)

DEPS_PNG_INCLUDE=$(FREELINX_BUILD_DIR)/deps/libpng/include
DEPS_ZLIB_INCLUDE=$(FREELINX_BUILD_DIR)/deps/zlib/include
DEPS_FT_INCLUDE=$(FREELINX_BUILD_DIR)/deps/freetype/include/freetype2
DEPS_PNG_LIB=$(FREELINX_BUILD_DIR)/deps/libpng/lib
DEPS_ZLIB_LIB=$(FREELINX_BUILD_DIR)/deps/zlib/lib
DEPS_FT_LIB=$(FREELINX_BUILD_DIR)/deps/freetype/lib

include ../../mk/project-port.mk

export PKG_CONFIG:=/usr/bin/pkg-config --static

STATIC_FLAGS=$(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) -O2 -DIMLIB2_STATIC_LOADERS

# One configure invocation + main lib build.  Make runs out-of-tree from the
# work dir via SRC_TREE, so build products land in $(SRC_TREE) (in-tree).
PROJECT_CFG_CMDS = \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(IMLIB_PREFIX)" \
		--disable-shared --enable-static \
		--disable-filters --disable-progs \
		--with-x \
		--x-includes="$(FLX_PREFIX)/include" \
		--x-libraries="$(FLX_PREFIX)/lib" \
		--enable-text \
		--disable-rtld-local-support \
		--with-png --with-zlib \
		--without-jpeg --without-gif --without-tiff --without-webp \
		--without-bz2 --without-lzma --without-id3 \
		--without-avif --without-heif --without-j2k --without-jxl \
		--without-ps --without-raw --without-svg --without-y4m \
		--without-x-shm-fd

BUILD_CMDS = \
	make -j"$(FREELINX_JOBS)" && \
	mkdir -p "$(OBJ_DIR)" && \
	for l in ani argb bmp ff ico lbm pnm png qoi tga xbm xpm zlib; do \
		$(FREELINX_CC) $(STATIC_FLAGS) \
			-I"$(SRC_TREE)" \
			-I"$(SRC_TREE)/src/lib" \
			-I"$(FREELINX_BUILD_DIR)/deps/x11/include" \
			-I"$(DEPS_PNG_INCLUDE)" -I"$(DEPS_ZLIB_INCLUDE)" \
			"-DPACKAGE_DATA_DIR=\"/usr/share/imlib2\"" \
			-DHAVE_CONFIG_H -DIMLIB2_STATIC_LOADERS \
			-Dloader=flx_loader_$$l \
			-c "$(SRC_TREE)/src/modules/loaders/loader_$$l.c" -o "$(OBJ_DIR)/loader_$$l.o" || exit 1; \
	done && \
	$(FREELINX_CC) $(STATIC_FLAGS) \
		-I"$(SRC_TREE)" \
		-I"$(SRC_TREE)/src/lib" $(FLX_PROJECT_CPPFLAGS) \
		-DHAVE_CONFIG_H -DIMLIB2_STATIC_LOADERS \
		-c "$(SRC_TREE)/src/modules/loaders/ldrs_util.c" -o "$(OBJ_DIR)/ldrs_util.o" && \
	$(FREELINX_CC) $(STATIC_FLAGS) \
		-I"$(SRC_TREE)" \
		-I"$(SRC_TREE)/src/lib" $(FLX_PROJECT_CPPFLAGS) \
		-DHAVE_CONFIG_H -DIMLIB2_STATIC_LOADERS \
		-c "$(SRC_TREE)/src/modules/loaders/decompress_load.c" -o "$(OBJ_DIR)/decompress_load.o" && \
	$(FREELINX_AR) rs "$(SRC_TREE)/src/lib/.libs/libImlib2.a" "$(OBJ_DIR)"/loader_*.o "$(OBJ_DIR)/ldrs_util.o" "$(OBJ_DIR)/decompress_load.o" && \
	mkdir -p "$(IMLIB_PREFIX)/lib/pkgconfig" "$(IMLIB_PREFIX)/include" && \
	cp -f "$(SRC_TREE)/src/lib/.libs/libImlib2.a" "$(IMLIB_PREFIX)/lib/libImlib2.a" && \
	cp -f "$(SRC_TREE)/src/lib/Imlib2.h" "$(SRC_TREE)/src/lib/Imlib2_Loader.h" "$(IMLIB_PREFIX)/include/" && \
	printf 'prefix=%s\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\n\nName: imlib2\nDescription: image loading and rendering library\nVersion: 1.12.7\nLibs: -L${libdir} -lImlib2\nCflags: -I${includedir}\n' "$(IMLIB_PREFIX)" > "$(IMLIB_PREFIX)/lib/pkgconfig/imlib2.pc"
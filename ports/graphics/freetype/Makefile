# FreeLinX/ports - graphics/freetype : FreeType font library (2.13.3).
#
# Needed by fontconfig/cairo (text rendering).  Static CMake build into the
# deps prefix; PIC (weston links static deps into shared plugin modules).
# HarfBuzz/Brotli/BZip2 disabled (upstream optional); zlib+libpng enabled.
NAME    := freetype
VERSION := 2.13.3
CATEGORY:= graphics
LICENSE := FTL
DEPENDENCIES:= zlib, libpng
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

FT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
CMAKE := /usr/bin/cmake
ZLIB    = $(FREELINX_BUILD_DIR)/deps/zlib
LIBPNG  = $(FREELINX_BUILD_DIR)/deps/libpng
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/freetype-VER-2-13-3

PROJECT_BIN = $(FT_PREFIX)/lib/libfreetype.a
BUILD_BIN   = $(PROJECT_BIN)

PROJECT_CFG_CMDS = \
	mkdir -p "$(SRC_TREE)/build" && \
	cd "$(SRC_TREE)/build" && \
	"$(CMAKE)" .. \
		-DCMAKE_SYSTEM_NAME=Linux \
		-DCMAKE_SYSTEM_PROCESSOR=x86_64 \
		-DCMAKE_C_COMPILER="$(FREELINX_TOOLCHAIN_BIN)/freelinix-cc" \
		-DCMAKE_C_LINK_EXECUTABLE="<CMAKE_C_COMPILER> <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LIBRARIES>" \
		-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
		-DCMAKE_INSTALL_PREFIX="$(FT_PREFIX)" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DZLIB_ROOT="$(ZLIB)" \
		-DZLIB_INCLUDE_DIR="$(ZLIB)/include" \
		-DZLIB_LIBRARY="$(ZLIB)/lib/libz.a" \
		-DPNG_PNG_INCLUDE_DIR="$(LIBPNG)/include" \
		-DPNG_LIBRARY="$(LIBPNG)/lib/libpng16.a" \
		-DFT_DISABLE_BROTLI=ON \
		-DFT_DISABLE_BZIP2=ON \
		-DFT_DISABLE_HARFBUZZ=ON \
		-DBUILD_SHARED_LIBS=OFF

BUILD_CMDS = \
	cd "$(SRC_TREE)/build" && \
	"$(CMAKE)" --build . -j"$(FREELINX_JOBS)" && \
	"$(CMAKE)" --install .
# FreeLinX/ports - graphics/libpng : Portable Network Graphics library (1.6.43).
#
# PNG library; feeds freetype/cairo/weston.  Static CMake build into the deps
# prefix.  Must be PIC: weston links its static deps into shared plugin
# modules.  CMake from host-tools; zlib dev dependency.
NAME    := libpng
VERSION := 1.6.43
CATEGORY:= graphics
LICENSE := libpng
DEPENDENCIES:= zlib
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

PNG_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
CMAKE := /usr/bin/cmake
ZLIB    = $(FREELINX_BUILD_DIR)/deps/zlib
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libpng-$(VERSION)

PROJECT_BIN = $(PNG_PREFIX)/lib/libpng16.a
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
		-DCMAKE_INSTALL_PREFIX="$(PNG_PREFIX)" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DZLIB_ROOT="$(ZLIB)" \
		-DPNG_SHARED=OFF \
		-DPNG_TESTS=OFF

BUILD_CMDS = \
	cd "$(SRC_TREE)/build" && \
	"$(CMAKE)" --build . --target png_static -j"$(FREELINX_JOBS)" && \
	"$(CMAKE)" --install .
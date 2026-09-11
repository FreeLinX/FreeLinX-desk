# FreeLinX/ports - graphics/expat : Expat XML parser library (2.7.1).
#
# xkeyboard-config / fontconfig / cairo dependency.  Static CMake build into
# the deps prefix.  Must be PIC because weston links its static deps into
# shared plugin modules.
NAME    := expat
VERSION := 2.7.1
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

EXPAT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
CMAKE := /usr/bin/cmake
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libexpat-R_2_7_1/expat

PROJECT_BIN = $(EXPAT_PREFIX)/lib/libexpat.a
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
		-DCMAKE_INSTALL_PREFIX="$(EXPAT_PREFIX)" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DEXPAT_SHARED_LIBS=OFF \
		-DEXPAT_BUILD_TOOLS=OFF \
		-DEXPAT_BUILD_EXAMPLES=OFF \
		-DEXPAT_BUILD_TESTS=OFF \
		-DEXPAT_WITH_LIBBSD=OFF

BUILD_CMDS = \
	cd "$(SRC_TREE)/build" && \
	"$(CMAKE)" --build . --target expat -j"$(FREELINX_JOBS)" && \
	"$(CMAKE)" --install .
# FreeLinX/ports - graphics/fontconfig : Font configuration library (2.15.0).
#
# Text-config for cairo/weston.  Static meson cross build into the deps
# prefix.  Freetype + expat are the XML/font dependencies.
NAME    := fontconfig
VERSION := 2.15.0
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:= freetype, expat, zlib, libpng
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

FC_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON := /home/devuan/.local/venvs/meson/bin/meson
DEPS  := $(FREELINX_BUILD_DIR)/deps
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/fontconfig-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson

PROJECT_BIN = $(FC_PREFIX)/lib/libfontconfig.a
BUILD_BIN   = $(PROJECT_BIN)

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(FC_PREFIX)" \
		-Dbaseconfig-dir=/etc/fonts \
		-Dcache-dir=/var/cache/fontconfig \
		-Dtools=disabled -Dtests=disabled -Ddoc=disabled \
		-Dnls=disabled -Dcache-build=disabled -Diconv=enabled \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" -j"$(FREELINX_JOBS)" && \
	DESTDIR="$(FC_PREFIX)" "$(MESON)" install -C "$(BUILD_DIR)" && \
	_NEST="$(FC_PREFIX)/home/devuan/FreeLinX/desktop-test/ports/build/deps/fontconfig" && \
	[ -d "$$_NEST" ] && cp -a "$$_NEST"/. "$(FC_PREFIX)"/ && rm -rf "$(FC_PREFIX)/home" || true
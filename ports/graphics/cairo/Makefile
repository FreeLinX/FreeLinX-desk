# FreeLinX/ports - graphics/cairo : 2D graphics library, vector rendering (1.18.2).
#
# Required unconditionally by weston (shared/ cairo-util and frame drawing).
# Static meson cross build; fontconfig+freetype+png+zlib enabled, X11/GL/
# xcb backends auto-disabled (deps not present).  PIC via meson default.
NAME    := cairo
VERSION := 1.18.2
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:= pixman, fontconfig, freetype, libpng, zlib
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

CAIRO_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON := /home/devuan/.local/venvs/meson/bin/meson
DEPS  := $(FREELINX_BUILD_DIR)/deps
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/cairo-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson

PROJECT_BIN = $(CAIRO_PREFIX)/lib/libcairo.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(CAIRO_PREFIX)" \
		-Dtests=disabled -Dfontconfig=enabled -Dfreetype=enabled \
		-Dpng=enabled -Dzlib=enabled -Dgtk_doc=false \
		-Dsymbol-lookup=disabled -Dglib=enabled -Dspectre=disabled \
		-Dgtk2-utils=disabled -Dxlib=enabled -Dxcb=enabled \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" -j"$(FREELINX_JOBS)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
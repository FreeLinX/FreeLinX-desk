# FreeLinX/ports - graphics/cairo-1.18.4 : cairo-1.18.4 1.18.4. Static cross build.
NAME    := cairo-1.18.4
VERSION := 1.18.4
CATEGORY:= graphics
LICENSE := CAIRO-1.18.4 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libcairo.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	PKG_CONFIG_LIBDIR="$(PKG_CONFIG_LIBDIR)" PKG_CONFIG="$(PKG_CONFIG)" \
	"$(MESON)" setup \
		--wrap-mode=nofallback \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dtests=disabled -Dpng=enabled -Dfreetype=enabled -Dfontconfig=enabled -Dzlib=enabled -Dxlib=enabled -Dxcb=enabled -Dxlib-xcb=enabled -Dquartz=disabled -Ddwrite=disabled -Dtee=disabled -Dtests=disabled -Dlzo=disabled -Dgtk2-utils=disabled -Dglib=enabled -Dspectre=disabled -Dsymbol-lookup=disabled -Dgtk_doc=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

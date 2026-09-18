# FreeLinX/ports - graphics/wayland-protocols : Wayland protocols (1.40)
NAME    := wayland-protocols
VERSION := 1.40
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:= wayland
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

WP_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON     := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE  = $(FREELINX_BUILD_DIR)/work/$(NAME)/wayland-protocols-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson

PROJECT_BIN = $(WP_PREFIX)/share/pkgconfig/wayland-protocols.pc
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	PKG_CONFIG_LIBDIR="$$PKG_CONFIG_LIBDIR:/tmp/host-wl/lib/pkgconfig" \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/../wayland/meson-cross.ini" \
		--buildtype=release \
		--prefix="$(WP_PREFIX)" \
		-Dtests=false \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

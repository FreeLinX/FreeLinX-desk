# FreeLinX/ports - graphics/gdk-pixbuf-2.42.12 : gdk-pixbuf-2.42.12 2.42.12. Static cross build.
NAME    := gdk-pixbuf-2.42.12
VERSION := 2.42.12
CATEGORY:= graphics
LICENSE := GDK-PIXBUF-2.42.12 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libgdk_pixbuf-2.0.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	sed -i "/executable('timescale'/d" gdk-pixbuf/pixops/meson.build && \
	sed -i '/gdkpixbuf_bin = \[/,/foreach/{/gdk-pixbuf-csource/d;/gdk-pixbuf-pixdata/d}' gdk-pixbuf/meson.build && \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dpng=enabled -Djpeg=disabled -Dtiff=disabled -Dgif=disabled -Dothers=disabled -Dbuiltin_loaders=png -Dtests=false -Dinstalled_tests=false -Dgtk_doc=false -Ddocs=false -Dintrospection=disabled -Dman=false -Dgio_sniffing=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

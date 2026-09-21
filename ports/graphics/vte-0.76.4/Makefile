# FreeLinX/ports - graphics/vte-0.76.4 : vte-0.76.4 (GTK3 terminal widget). Static cross build (C++).
NAME    := vte-0.76.4
VERSION := 0.76.4
CATEGORY:= graphics
LICENSE := LGPL-2.1-or-later
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libvte-2.91.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

export PATH := $(FREELINX_VENV_BIN):$(FREELINX_BUILD_DIR)/deps/glib-2.82.5/bin:$(PATH)

PROJECT_CFG_CMDS = \
	awk -f "$(CURDIR)/strip-reflect.awk" src/meson.build > src/meson.build.new && mv src/meson.build.new src/meson.build && \
	sed -i 's/shared_library(/static_library(/; s/    version: libvte_gtk[34]_soversion,//; /^subdir(.app.)$$/d' src/meson.build && \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dgir=false -Dvapi=false -Dgtk4=false -Dgnutls=false -Dicu=false -D_systemd=false -Dglade=false -Ddocs=false -Ddbg=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
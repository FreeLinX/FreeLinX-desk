# FreeLinX/ports - graphics/gtk-3.24.52 : gtk-3.24.52 3.24.52. Static cross build.
NAME    := gtk-3.24.52
VERSION := 3.24.52
CATEGORY:= graphics
LICENSE := GTK-3.24.52 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libgtk-3.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dwayland_backend=true -Dx11_backend=false -Dbroadway_backend=false -Dintrospection=false -Dcloudproviders=false -Dtests=false -Dexamples=false -Ddemos=false -Dcolord=no -Dprofiler=false -Dtracker3=false -Dman=false -Dgtk_doc=false -Dprint_backends=file -Dbuiltin_immodules=none -Dlibepoxy:glx=no -Dlibepoxy:egl=auto -Dlibepoxy:x11=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

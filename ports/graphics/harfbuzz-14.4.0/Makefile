# FreeLinX/ports - graphics/harfbuzz-14.4.0 : harfbuzz-14.4.0 14.4.0. Static cross build.
NAME    := harfbuzz-14.4.0
VERSION := 14.4.0
CATEGORY:= graphics
LICENSE := HARFBUZZ-14.4.0 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libharfbuzz.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dfreetype=enabled -Dutilities=disabled -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

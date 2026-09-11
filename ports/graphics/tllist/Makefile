# FreeLinX/ports - graphics/tllist : tllist 1.1.0 (type list, header-only).
#
# Small C header library used by fcft/foot for type-safe linked lists.
NAME    := tllist
VERSION := 1.1.0
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

TL_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(TL_PREFIX)/include/tllist.h
BUILD_BIN   = $(PROJECT_BIN)

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(TL_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" install -C "$(BUILD_DIR)"
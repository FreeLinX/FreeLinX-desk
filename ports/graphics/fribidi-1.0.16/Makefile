# FreeLinX/ports - graphics/fribidi-1.0.16 : fribidi-1.0.16 1.0.16. Static cross build.
NAME    := fribidi-1.0.16
VERSION := 1.0.16
CATEGORY:= graphics
LICENSE := FRIBIDI-1.0.16 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libfribidi.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Ddocs=false -Dtests=false -Dbin=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

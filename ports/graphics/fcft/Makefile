# FreeLinX/ports - graphics/fcft : fcft 3.3.3 (font loading and glyph rasterization).
#
# Fontcache/font render library for foot: builds on freetype2 + fontconfig,
# rasterizes glyphs into caller-provided buffers.  Static cross build.
NAME    := fcft
VERSION := 3.3.3
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= tllist, freetype, fontconfig, utf8proc
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FCFT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FCFT_PREFIX)/lib/libfcft.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Ddocs=disabled -Dexamples=false \
		-Dgrapheme-shaping=disabled -Drun-shaping=disabled \
		-Dtest-text-shaping=false \
		--prefix="$(FCFT_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
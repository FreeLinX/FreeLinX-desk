# FreeLinX/ports - graphics/pixman : pixman 0.44.2 (build dependency).
#
# Pixel-manipulation library (scanline compositing) used by Wayland
# compositors (pixman-renderer in weston/wlroots) and by cairo.  Cross-built
# static against the FreeLinX musl sysroot; installed only into
# build/deps/pixman.
#
# An SIMD-optimized implementation is enabled for the x86-64 target
# automatically when the compiler supports it.

NAME   := pixman
VERSION:= 0.44.2
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

PIX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libpixman-1.a

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS := /tmp/opencode/host-tools
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/pixman-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(PIX_PREFIX)/lib/libpixman-1.a

export PATH := $(HOST_TOOLS):$(PATH)

PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(PIX_PREFIX)" \
		-Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dopenmp=disabled \
		-Dloongson-mmi=disabled -Dgnuplot=false -Dtimers=false \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
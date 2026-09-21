# FreeLinX/ports - graphics/libxkbcommon : libxkbcommon 1.7.0 (build dependency).
#
# Keyboard keymap compiler + lookup (xkbcommon API) used by Wayland
# compositors to map scancodes to keysyms.  Cross-built static against the
# FreeLinX musl sysroot; installed into build/deps/libxkbcommon.  The keyboard
# layout DATA (xkeyboard-config) is a separate data package installed at the
# target's /usr/share/X11/xkb; xkb-config-root is hard-coded to that runtime
# path.  X11/xkbregistry/wayland integrations and tools are disabled for the
# dependency build.

NAME   := libxkbcommon
VERSION:= 1.7.0
CATEGORY:= graphics
LICENSE:= MIT/X11
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

XKB_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libxkbcommon.a

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS ?= $(FREELINX_HOST_TOOLS)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libxkbcommon-xkbcommon-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(XKB_PREFIX)/lib/libxkbcommon.a

export PATH := $(HOST_TOOLS):$(PATH)

PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(XKB_PREFIX)" \
		-Denable-x11=false -Denable-xkbregistry=false \
		-Denable-wayland=false -Denable-tools=false \
		-Denable-docs=false -Denable-bash-completion=false \
		-Dxkb-config-root=/usr/share/X11/xkb \
		-Dx-locale-root=/usr/share/X11/locale \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
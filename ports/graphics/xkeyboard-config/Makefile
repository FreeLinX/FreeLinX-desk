# FreeLinX/ports - graphics/xkeyboard-config : X keyboard configuration data (2.44).
#
# Layout/keycodes/symbols data for libxkbcommon, installed as pure data at
# datadir/X11/xkb (weston/libxkbcommon compile-time root /usr/share/X11/xkb).
# Built with the HOST meson (data-only; python-driven generators run on host).
NAME    := xkeyboard-config
VERSION := 2.44
CATEGORY:= graphics
LICENSE := MIT/X11
DEPENDENCIES:=
BUILD_DEPENDENCIES:= (host only, data-only build)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

XKB_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/xkeyboard-config-xkeyboard-config-2.44-1691aef8fa12f63037f2ff956f902587d814a65c
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/native

PROJECT_BIN = $(XKB_PREFIX)/share/X11/xkb/rules/evdev
BUILD_BIN   = $(PROJECT_BIN)

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--buildtype=release \
		-Ddatadir=share \
		-Dcompat-rules=false -Dxorg-rules-symlinks=false \
		-Dxkb-base=/usr/share/X11/xkb \
		--prefix="$(XKB_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" -j"$(FREELINX_JOBS)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
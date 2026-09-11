# FreeLinX/ports - graphics/foot : foot 1.28.0 (Wayland terminal emulator).
#
# The default FreeLinX terminal: pure-Wayland client, tiny C, static build.
# Renders via fcft; input via libxkbcommon; clipboard/scale from the Wayland
# protocols.  Debian/tests/docs/terminfo disabled for the base image.
NAME    := foot
VERSION := 1.28.0
CATEGORY:= graphics
LICENSE := MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= fcft, tllist, utf8proc, wayland, libxkbcommon, fontconfig, wayland-protocols
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FOOT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FOOT_PREFIX)/bin/foot
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

export PATH := /tmp/opencode/host-tools:/tmp/opencode/host-wl/bin:$(PATH)

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		-Ddocs=disabled -Dtests=false -Dthemes=false \
		-Dime=false -Dgrapheme-clustering=disabled \
		-Dterminfo=disabled -Dutmp-backend=none \
		--prefix="$(FOOT_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
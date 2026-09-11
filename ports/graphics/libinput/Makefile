# FreeLinX/ports - graphics/libinput : libinput 1.27.1 (build dependency).
#
# Input device handling for Wayland compositors: opens /dev/input/event*
# via libevdev, discovers devices via libudev (provided by libudev-zero, a
# drop-in daemonless udev), and normalizes events (pointer keys touchpad).
# Cross-built static against the FreeLinX musl sysroot; installed into
# build/deps/libinput.  libwacom/tests/GUI/docs disabled for the dependency
# build.

NAME   := libinput
VERSION:= 1.27.1
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl, libevdev, libudev-zero
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

LI_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libinput.so

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS := /tmp/opencode/host-tools
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libinput-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(LI_PREFIX)/lib/libinput.so

export PATH := $(HOST_TOOLS):$(PATH)
# Contain pkg-config lookups to our dep prefixes + musl sysroot .pc dirs.
export PKG_CONFIG_PATH := \
	$(FREELINX_BUILD_DIR)/deps/libevdev/lib/pkgconfig:$(FREELINX_BUILD_DIR)/deps/libudev-zero/lib/pkgconfig:$(FREELINX_BUILD_DIR)/deps/mtdev/lib/pkgconfig

PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=both \
		--prefix="$(LI_PREFIX)" \
		-Dtests=false -Ddebug-gui=false -Ddocumentation=false \
		-Dlibwacom=false -Dinstall-tests=false -Dcoverity=false \
		-Dudev-dir="$(LI_PREFIX)/lib/udev" -Depoll-dir="$(LI_PREFIX)/libexec" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
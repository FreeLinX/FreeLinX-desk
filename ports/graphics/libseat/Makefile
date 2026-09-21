# FreeLinX/ports - graphics/libseat : libseat 0.9.1 (build dependency).
#
# Seat management library used by Wayland compositors (weston) to open and
# master the DRM/KMS devices.  Built as the libseat part of the seatd 0.9.1
# upstream package with the *builtin* backend: an embedded seatd that grants
# direct device access (perfect for the root initramfs, no daemon/socket
# needed).  The seatd server and logind backends are not built.  Installed
# into build/deps/libseat.

NAME   := libseat
VERSION:= 0.9.1
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

SEAT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= include/libseat.h

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS ?= $(FREELINX_HOST_TOOLS)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/seatd-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(SEAT_PREFIX)/include/libseat.h

export PATH := $(HOST_TOOLS):$(PATH)

PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(SEAT_PREFIX)" \
		-Dlibseat-builtin=enabled -Dlibseat-seatd=enabled \
		-Dlibseat-logind=disabled -Dserver=disabled \
		-Dexamples=disabled -Dman-pages=disabled \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
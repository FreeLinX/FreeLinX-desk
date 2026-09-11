# FreeLinX/ports - graphics/wayland : Wayland 1.23.1 (build dependency).
#
# The Wayland protocol libraries (libwayland-server, libwayland-client,
# libwayland-cursor, libwayland-egl).  Cross-built against the FreeLinX musl
# sysroot; protocol code generation is done by a HOST-built wayland-scanner
# (built natively into /tmp/opencode/host-wl) because the target binary cannot
# run on the build host.  Installed into the build/deps/wayland prefix;
# compositors and client libs consume the static archives.
#
# Native wayland-scanner is provided via meson-native.ini (binaries + a
# wayland-scanner.pc); the cross file drives the target compiler.

NAME   := wayland
VERSION:= 1.23.1
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl, native host wayland-scanner
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

WAY_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libwayland-server.a

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS := /tmp/opencode/host-tools
HOST_WL := /tmp/opencode/host-wl
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/wayland-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(WAY_PREFIX)/lib/libwayland-server.a

export PATH := $(HOST_TOOLS):$(PATH)
# Native wayland-scanner pkg-config for the cross build's native dependency.
export PKG_CONFIG_PATH := $(HOST_WL)/lib/pkgconfig

# ffis included in the sysroot; wayland uses its own ffi checks against the
# musl libc (no libffi dependency at build time).
PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--native-file "$(PORT_DIR)/meson-native.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(WAY_PREFIX)" \
		-Dlibraries=true -Dscanner=false \
		-Ddtd_validation=false -Ddocumentation=false -Dtests=false \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
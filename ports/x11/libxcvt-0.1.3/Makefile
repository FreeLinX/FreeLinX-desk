# FreeLinX/ports - x11/libxcvt-0.1.3 : libxcvt (CVT modeline helper). Meson.
NAME    := libxcvt-0.1.3
VERSION := 0.1.3
CATEGORY:= x11
LICENSE := MIT-X11
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/x11
MESON    := /home/devuan/.local/venvs/meson/bin/meson
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libxcvt.a
BUILD_BIN   = $(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS?=

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	sed -i 's/shared_library(/library(/' lib/meson.build && \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	PKG_CONFIG_LIBDIR="$(PKG_CONFIG_LIBDIR)" PKG_CONFIG="$(PKG_CONFIG)" \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
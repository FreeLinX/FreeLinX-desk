# FreeLinX/ports - xfce/libxfce4util-4.20.1 : Xfce base utility library.
NAME:=libxfce4util-4.20.1
CATEGORY:=xfce
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=LGPL-2.0-or-later

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON ?= $(FREELINX_MESON)
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR=$(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN=$(FLX_PREFIX)/lib/libxfce4util-1.0.a
BUILD_BIN=$(PROJECT_BIN)

include ../../mk/project-port.mk

export PATH := $(FREELINX_VENV_BIN):$(FREELINX_BUILD_DIR)/deps/glib-2.82.5/bin:$(PATH)

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dintrospection=false -Dvala=disabled \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
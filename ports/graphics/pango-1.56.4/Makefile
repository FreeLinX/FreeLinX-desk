# FreeLinX/ports - graphics/pango-1.56.4 : pango-1.56.4 1.56.4. Static cross build.
NAME    := pango-1.56.4
VERSION := 1.56.4
CATEGORY:= graphics
LICENSE := PANGO-1.56.4 Public
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(FLX_PREFIX)/lib/libpango-1.0.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# host-tools dir absent on this machine; PATH untouched

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--wrap-mode=nofallback \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Ddocumentation=false -Dman-pages=false -Dintrospection=disabled -Dbuild-testsuite=false -Dbuild-examples=false -Dfontconfig=enabled -Dsysprof=disabled -Dlibthai=disabled -Dcairo=enabled -Dxft=disabled -Dfreetype=enabled \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"

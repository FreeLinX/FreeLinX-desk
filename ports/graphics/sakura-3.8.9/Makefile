# FreeLinX/ports - graphics/sakura-3.8.9 : vte-2.91 based terminal emulator.
# Fast static cross build via CMake. Uses the shared FreeLinX PC (gtk/vte/pcre2).
NAME:=sakura-3.8.9
CATEGORY:=graphics
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=GPL-3.0-or-later

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/$(NAME)
CMAKE ?= $(FREELINX_CMAKE)
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR=$(FREELINX_BUILD_DIR)/obj/$(NAME)/cmake
PROJECT_BIN=$(FLX_PREFIX)/bin/sakura
BUILD_BIN=$(PROJECT_BIN)

include ../../mk/project-port.mk

# cross.cmake resolves the toolchain via its environment (never an
# absolute path): pass the configured FreeLinX toolchain through.
export FREELINX_TOOLCHAIN_DIR := $(FREELINX_TOOLCHAIN_DIR)

PROJECT_CFG_CMDS = \
	sh "$(CURDIR)/patch-cfg.sh" && \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(CMAKE)" -S . -B "$(BUILD_DIR)" \
		-DCMAKE_TOOLCHAIN_FILE="$(CURDIR)/cross.cmake" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$(FLX_PREFIX)" \
		-DCMAKE_EXE_LINKER_FLAGS="-static"

BUILD_CMDS = \
	"$(CMAKE)" --build "$(BUILD_DIR)" --parallel "$$(nproc --ignore=1)" && \
	"$(CMAKE)" --install "$(BUILD_DIR)"
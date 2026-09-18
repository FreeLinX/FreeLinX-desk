# FreeLinX/ports - x11/libSM-1.2.5 : libSM (X Session Management library).
NAME:=libSM-1.2.5
CATEGORY:=x11
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11
DEPENDENCIES:=
BUILD_DEPENDENCIES:=libICE-1.1.2

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN=$(FLX_PREFIX)/lib/libSM.a
BUILD_BIN=$(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS?=

include ../../mk/project-port.mk

export PKG_CONFIG:=/usr/bin/pkg-config --static

PROJECT_CFG_CMDS = \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(FLX_PREFIX)" \
		--disable-shared --enable-static \
		--disable-dependency-tracking \
		--without-libibuus \

BUILD_CMDS = make && make install
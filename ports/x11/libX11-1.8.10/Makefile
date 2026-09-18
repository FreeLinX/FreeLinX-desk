# FreeLinX/ports - x11/libX11-1.8.10 : libX11 (X Window System).
NAME:=libX11-1.8.10
CATEGORY:=x11
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN=$(FLX_PREFIX)/lib/libX11.a
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
		

BUILD_CMDS = make && make install && \
	sed -i 's|^Libs: -L${libdir} -lX11$$|Libs: -L${libdir} -lX11 -lXau -lXdmcp|' \
		"$(FLX_PREFIX)/lib/pkgconfig/x11.pc"

# FreeLinX/ports - x11/libxshmfence-1.3.2 : libxshmfence (DRM sync fences).
#
# xorg-server requires xshmfence >= 1.1 to build DRI3, and DRI3 is required by
# the modesetting DDX.  The library is a thin client-side wrapper over the
# kernel's DRM sync_file fds; without it configure aborts with
# "DRI3 requested, but xshmfence not found".
#
# 1.3.2 ships autotools only (no meson.build), so this recipe configures in
# tree like x11/xorg-server-21.1.24 does.  Built as a static archive into the
# shared x11 dep prefix so both xorg-server and xf86-video-modesetting link it.
NAME    := libxshmfence-1.3.2
VERSION := 1.3.2
CATEGORY:= x11
LICENSE := MIT-X11
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

FLX_PREFIX = $(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN = $(FLX_PREFIX)/lib/libxshmfence.a
BUILD_BIN   = $(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS?=

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(FLX_PREFIX)" \
		--disable-shared --enable-static \
		--disable-dependency-tracking \
		--without-xml \
		--disable-docs

BUILD_CMDS = \
	make && make install

NAME := nsxiv
VERSION := 32
CATEGORY := graphics
TARGET := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0-only
DEPENDENCIES := graphics/imlib2-1.12.7, x11/libX11-1.8.10, x11/libXft-2.3.8, graphics/fontconfig, graphics/freetype

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

NSXIV_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := nsxiv
INSTALL_RELPATH := bin/nsxiv

PROJECT_BIN := $(NSXIV_PREFIX)/bin/nsxiv
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(FREELINX_SYSROOT)/include -I$(FREELINX_SYSROOT)/include/freetype2 \
	-D_XOPEN_SOURCE=700 -DHAVE_LIBEXIF=0 -DHAVE_LIBFONTS=1 -DHAVE_INOTIFY=1
FLX_PROJECT_LDFLAGS = -L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	cp -f config.def.h config.h && \
	cp -f $(PORTDIR)/version.h .

BUILD_CMDS = \
	$(CC) $(CFLAGS) -I. autoreload.c commands.c image.c main.c options.c thumbs.c util.c window.c $(LDFLAGS) \
		-lImlib2 \
		-lXft -lfontconfig -lfreetype \
		-lXext -lXrender -lX11 -lxcb -lXau -lXdmcp \
		-lpng -lz -lexpat -lm \
		-o nsxiv && \
	mkdir -p "$(NSXIV_PREFIX)/bin" && \
	cp -f nsxiv "$(NSXIV_PREFIX)/bin/nsxiv" && \
	ln -sf nsxiv "$(NSXIV_PREFIX)/bin/sxiv" && \
	$(STRIP) "$(NSXIV_PREFIX)/bin/nsxiv"

NAME := dwm
VERSION := 6.5
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := MIT
DEPENDENCIES := x11/libX11-1.8.10, x11/libXinerama-1.1.5, x11/libXft-2.3.8, graphics/fontconfig, graphics/freetype

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

DWM_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := dwm
INSTALL_RELPATH := bin/dwm

PROJECT_BIN := $(DWM_PREFIX)/bin/dwm
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(PORTDIR) -I$(FREELINX_SYSROOT)/include -I$(FREELINX_SYSROOT)/include/freetype2
FLX_PROJECT_LDFLAGS = -L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = cp -f $(PORTDIR)/config.h .

BUILD_CMDS = \
	$(CC) $(CFLAGS) -DVERSION=\"$(VERSION)\" drw.c dwm.c util.c $(LDFLAGS) \
		-lXinerama -lXext -lXft -lfontconfig -lfreetype \
		-lXrender -lX11 -lxcb -lXau -lXdmcp \
		-lexpat -lpng -lz -lm \
		-o dwm && \
	mkdir -p "$(DWM_PREFIX)/bin" && \
	cp -f dwm "$(DWM_PREFIX)/bin/dwm" && \
	$(STRIP) "$(DWM_PREFIX)/bin/dwm"

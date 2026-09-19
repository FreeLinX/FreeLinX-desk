# FreeLinX/ports - graphics/xclip : xclip 0.13 (X11 clipboard utility).
NAME := xclip
VERSION := 0.13
CATEGORY := graphics
TARGET := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0+
DEPENDENCIES := x11/libX11-1.8.10

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

XC_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := xclip
INSTALL_RELPATH := bin/xclip

PROJECT_BIN := $(XC_PREFIX)/bin/xclip
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(FREELINX_SYSROOT)/include -DPACKAGE_NAME=\"xclip\" -DVERSION=\"$(VERSION)\" -DPACKAGE_VERSION=\"$(VERSION)\"
FLX_PROJECT_LDFLAGS = -L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	mkdir -p X11/Xmu && \
	cp -f $(PORTDIR)/Atoms.h X11/Xmu/Atoms.h

BUILD_CMDS = \
	$(CC) $(CFLAGS) -I. xclip.c xclib.c xcprint.c $(LDFLAGS) \
		-lX11 -lxcb -lXau -lXdmcp \
		-o xclip && \
	mkdir -p "$(XC_PREFIX)/bin" && \
	cp -f xclip "$(XC_PREFIX)/bin/xclip" && \
	$(STRIP) "$(XC_PREFIX)/bin/xclip"
NAME := xinit
VERSION := 1.4.2
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := MIT
DEPENDENCIES := x11/libX11-1.8.10

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

XINIT_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := xinit
INSTALL_RELPATH := bin/xinit

PROJECT_BIN := $(XINIT_PREFIX)/bin/xinit
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(FREELINX_SYSROOT)/include -DBINDIR=\"/bin\" -DXINITDIR=\"/etc/X11/xinit\"
FLX_PROJECT_LDFLAGS = -L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = :

BUILD_CMDS = \
	$(CC) $(CFLAGS) xinit.c $(LDFLAGS) \
		-lX11 -lxcb -lXau -lXdmcp \
		-o xinit && \
	mkdir -p "$(XINIT_PREFIX)/bin" && \
	cp -f xinit "$(XINIT_PREFIX)/bin/xinit" && \
	cp -f $(PORTDIR)/startx "$(XINIT_PREFIX)/bin/startx" && \
	chmod 755 "$(XINIT_PREFIX)/bin/startx" && \
	$(STRIP) "$(XINIT_PREFIX)/bin/xinit"

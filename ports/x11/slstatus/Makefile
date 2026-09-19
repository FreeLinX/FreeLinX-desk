NAME := slstatus
VERSION := 1.0
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := ISC
DEPENDENCIES := x11/libX11-1.8.10

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

SLSTATUS_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := slstatus
INSTALL_RELPATH := bin/slstatus

PROJECT_BIN := $(SLSTATUS_PREFIX)/bin/slstatus
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(PORTDIR) -I$(FREELINX_SYSROOT)/include -D_DEFAULT_SOURCE
FLX_PROJECT_LDFLAGS = -L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = cp -f $(PORTDIR)/config.h .

BUILD_CMDS = \
	$(CC) $(CFLAGS) -DVERSION=\"$(VERSION)\" components/*.c util.c slstatus.c $(LDFLAGS) \
		-lX11 -lxcb -lXau -lXdmcp \
		-o slstatus && \
	mkdir -p "$(SLSTATUS_PREFIX)/bin" && \
	cp -f slstatus "$(SLSTATUS_PREFIX)/bin/slstatus" && \
	$(STRIP) "$(SLSTATUS_PREFIX)/bin/slstatus"

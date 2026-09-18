NAME := dmenu
VERSION := 5.3
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := MIT
DEPENDENCIES := x11/libX11-1.8.10, x11/libXinerama-1.1.5, x11/libXft-2.3.8, graphics/fontconfig, graphics/freetype

PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(abspath $(PORTDIR)/../../build)

DMENU_PREFIX := $(BUILD_DIR)/deps/$(NAME)
FLX_PREFIX := $(BUILD_DIR)/deps/x11

PREFIX := /
INSTALL_BIN := dmenu
INSTALL_RELPATH := bin/dmenu

PROJECT_BIN := $(DMENU_PREFIX)/bin/dmenu
BUILD_BIN := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS = -I$(FLX_PREFIX)/include -I$(FLX_PREFIX)/include/freetype2
FLX_PROJECT_LDFLAGS = -L$(FLX_PREFIX)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = :

FT_PREFIX := $(BUILD_DIR)/deps/freetype
FC_PREFIX := $(BUILD_DIR)/deps/fontconfig

BUILD_CMDS = \
	sed -i 's|^PREFIX = .*|PREFIX = $(DMENU_PREFIX)|' config.mk && \
	sed -i 's|^CC = .*|CC = $(CC)|' config.mk && \
	sed -i 's|^INCS = .*|INCS = -I$(FLX_PREFIX)/include -I$(FT_PREFIX)/include/freetype2 -I$(FC_PREFIX)/include|' config.mk && \
	sed -i 's|^LIBS = .*|LIBS = -L$(FLX_PREFIX)/lib -L$(FT_PREFIX)/lib -L$(FC_PREFIX)/lib -lXinerama -lXext -lXft -lfontconfig -lfreetype -lXrender -lX11 -lxcb -lXau -lXdmcp -lexpat -lpng16 -lz|' config.mk && \
	sed -i 's|^CFLAGS.*=.*|CFLAGS += -std=c99 -pedantic -Wall -Os $$(INCS) $$(CPPFLAGS)|' config.mk && \
	sed -i 's|^LDFLAGS.*=.*|LDFLAGS += $$(LIBS)|' config.mk && \
	make && \
	make install

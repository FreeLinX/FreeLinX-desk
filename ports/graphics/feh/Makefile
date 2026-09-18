# FreeLinX/ports - graphics/feh : feh image viewer (static musl build).
#
# feh is a hand-rolled Makefile project (no configure), so everything is
# driven through make variables.  Command-line LDLIBS overrides the closure
# since config.mk's LDLIBS += is ignored for command-line variables.
# musl lacks mkstemps/strverscmp, so both are forced off (feh carries its own
# strverscmp.c in that case).  curl/magic/exif/xinerama/inotify disabled.
NAME:=feh-3.13.1
VERSION:=3.13.1
CATEGORY:=graphics
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT
DEPENDENCIES:=imlib2-1.12.7, libPNG, libX11
INSTALL_BIN:=feh
INSTALL_RELPATH:=bin/$(INSTALL_BIN)

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
IMLIB_PREFIX=$(FREELINX_BUILD_DIR)/deps/imlib2
PNG_PREFIX=$(FREELINX_BUILD_DIR)/deps/libpng
ZLIB_PREFIX=$(FREELINX_BUILD_DIR)/deps/zlib
FT_PREFIX=$(FREELINX_BUILD_DIR)/deps/freetype
FEH_PREFIX=$(FREELINX_BUILD_DIR)/deps/feh

PROJECT_BIN=$(FEH_PREFIX)/bin/feh
BUILD_BIN=$(PROJECT_BIN)

FLX_PROJECT_LIBS?=
FLX_PROJECT_CFLAGS=-O2
FLX_PROJECT_CPPFLAGS=-I$(FLX_PREFIX)/include -I$(IMLIB_PREFIX)/include -I$(PNG_PREFIX)/include -I$(ZLIB_PREFIX)/include -I$(FT_PREFIX)/include/freetype2 -I$(FT_PREFIX)/include
FLX_PROJECT_LDFLAGS=-L$(FLX_PREFIX)/lib -L$(IMLIB_PREFIX)/lib -L$(PNG_PREFIX)/lib -L$(ZLIB_PREFIX)/lib -L$(FT_PREFIX)/lib

include ../../mk/project-port.mk

# Static link closure in dependency order (archives after the objects they
# satisfy; imlib2 pulls png/zlib/freetype/x11/xext).
FEH_LIBS=-lm -lpng -lX11 -lImlib2 -lXext -lxcb -lXau -lXdmcp -lz -lfreetype

# feh has no autotools configure script.
PROJECT_CFG_CMDS=:

BUILD_CMDS = \
	$(MAKE) -C src feh \
		curl=0 magic=0 exif=0 mkstemps=0 xinerama=0 verscmp=0 inotify=0 help=0 win=0 \
		LDLIBS="$(FEH_LIBS)" && \
	mkdir -p "$(FEH_PREFIX)/bin" && \
	cp -f src/feh "$(FEH_PREFIX)/bin/feh" && \
	$(STRIP) "$(FEH_PREFIX)/bin/feh"
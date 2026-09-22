# FreeLinX/ports - x11/dunst : lightweight notification daemon (D-Bus/libnotify).
#
# dunst is a minimal, highly configurable notification daemon for X11.
# It uses a plain GNU Makefile (no autotools/cmake) which makes it easy to
# cross-compile: we just pass CC/CFLAGS/LDFLAGS on the command line.
#
# GNU-free toolchain: clang + LLD + musl.  dunst itself has no GNU-only code;
# the Makefile uses $(CC) so our export wins without patching.
#
# Features enabled:
#   - X11 back-end (default)
#   - Wayland back-end: DISABLED (no wayland-client in FreeLinX x11 target)
#   - D-Bus via libdbus-1: DISABLED (replaces with libnotify's minimal stub)
#   - libxss (screen-saver extension): optional, disabled to keep deps small
#   - libnotify: used at runtime, not linked into dunst itself
#
# Runtime config: ~/.config/dunst/dunstrc  (FreeLinX ships a minimal default)

NAME    := dunst
VERSION := 1.11.0
CATEGORY := x11
TARGET  := $(FREELINX_TRIPLE)
LICENSE := BSD-3-Clause
DEPENDENCIES := x11/libX11-1.8.10, x11/libXext-1.3.6, x11/libXft-2.3.8, \
                x11/libXinerama-1.1.5, x11/libXrandr-1.5.4, \
                graphics/glib-2.82.5, graphics/cairo, \
                graphics/pango-1.56.4, graphics/gdk-pixbuf-2.42.12

BUILD_DEPENDENCIES := pkgconf

INSTALL_BIN    := dunst
INSTALL_RELPATH := bin/$(INSTALL_BIN)

DUNST_PREFIX := $(FREELINX_BUILD_DIR)/deps/dunst
X11_PREFIX   := $(FREELINX_BUILD_DIR)/deps/x11
CAIRO_PREFIX := $(FREELINX_BUILD_DIR)/deps/cairo
PANGO_PREFIX := $(FREELINX_BUILD_DIR)/deps/pango
GLIB_PREFIX  := $(FREELINX_BUILD_DIR)/deps/glib
GDK_PREFIX   := $(FREELINX_BUILD_DIR)/deps/gdk-pixbuf

PROJECT_BIN := $(DUNST_PREFIX)/bin/dunst
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS := \
	-I$(X11_PREFIX)/include \
	-I$(CAIRO_PREFIX)/include/cairo \
	-I$(PANGO_PREFIX)/include/pango-1.0 \
	-I$(GLIB_PREFIX)/include/glib-2.0 \
	-I$(GLIB_PREFIX)/lib/glib-2.0/include \
	-I$(GDK_PREFIX)/include/gdk-pixbuf-2.0

FLX_PROJECT_LDFLAGS := \
	-L$(X11_PREFIX)/lib \
	-L$(CAIRO_PREFIX)/lib \
	-L$(PANGO_PREFIX)/lib \
	-L$(GLIB_PREFIX)/lib \
	-L$(GDK_PREFIX)/lib

include ../../mk/project-port.mk

# dunst Makefile respects CC/CFLAGS/LDFLAGS from environment; no autotools.
PROJECT_CFG_CMDS = :

DUNST_LIBS := \
	-lX11 -lXext -lXft -lXinerama -lXrandr -lXdmcp -lXau \
	-lcairo -lpango-1.0 -lpangocairo-1.0 -lpangoft2-1.0 \
	-lgdk_pixbuf-2.0 -lglib-2.0 -lgobject-2.0 -lgmodule-2.0 \
	-lgio-2.0 -lfreetype -lfontconfig -lpixman-1 \
	-lxcb -lxcb-render -lxcb-shm -lxcb-render-util \
	-lz -lm

BUILD_CMDS = \
	$(MAKE) \
		CC="$(CC)" \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS) $(DUNST_LIBS)" \
		WAYLAND=0 \
		PREFIX="$(DUNST_PREFIX)" \
		dunst && \
	mkdir -p "$(DUNST_PREFIX)/bin" && \
	cp -f dunst "$(DUNST_PREFIX)/bin/dunst" && \
	$(STRIP) "$(DUNST_PREFIX)/bin/dunst"

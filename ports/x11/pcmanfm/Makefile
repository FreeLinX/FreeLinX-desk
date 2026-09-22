# FreeLinX/ports - x11/pcmanfm : PCMan File Manager (GTK-3 based).
#
# PCManFM is a lightweight graphical file manager from the LXDE project.
# It depends on libfm-gtk (libfm + GTK3) and GLib.  No GNOME/GNU dependencies
# beyond GLib (which is not GNU software) are required.
#
# Toolchain: clang + LLD + musl.
# pcmanfm uses autotools; cross-compile works by passing --host.
#
# Configure flags:
#   --disable-desktop-integration  no GDK/DBus desktop integration daemon
#   --disable-nls                  no GNU NLS / gettext dependency
#   --disable-schemas-compile      no GSettings schema at build time
#
# Dependencies: libfm, libfm-gtk, GTK3, GLib, GDK-PixBuf, Pango, Cairo, X11.

NAME    := pcmanfm
VERSION := 1.3.2
CATEGORY := x11
TARGET  := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := graphics/gtk-3.24.52, graphics/glib-2.82.5, \
                graphics/gdk-pixbuf-2.42.12, graphics/cairo, \
                graphics/pango-1.56.4, x11/libX11-1.8.10, \
                x11/libfm

BUILD_DEPENDENCIES := pkgconf

INSTALL_BIN    := pcmanfm
INSTALL_RELPATH := bin/$(INSTALL_BIN)

PCMANFM_PREFIX := $(FREELINX_BUILD_DIR)/deps/pcmanfm
GTK3_PREFIX    := $(FREELINX_BUILD_DIR)/deps/gtk-3
GLIB_PREFIX    := $(FREELINX_BUILD_DIR)/deps/glib
CAIRO_PREFIX   := $(FREELINX_BUILD_DIR)/deps/cairo
PANGO_PREFIX   := $(FREELINX_BUILD_DIR)/deps/pango
X11_PREFIX     := $(FREELINX_BUILD_DIR)/deps/x11

PROJECT_BIN := $(PCMANFM_PREFIX)/bin/pcmanfm
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS := \
	-I$(GTK3_PREFIX)/include/gtk-3.0 \
	-I$(GTK3_PREFIX)/include/gdk-3.0 \
	-I$(GLIB_PREFIX)/include/glib-2.0 \
	-I$(GLIB_PREFIX)/lib/glib-2.0/include \
	-I$(CAIRO_PREFIX)/include/cairo \
	-I$(PANGO_PREFIX)/include/pango-1.0 \
	-I$(X11_PREFIX)/include

FLX_PROJECT_LDFLAGS := \
	-L$(GTK3_PREFIX)/lib \
	-L$(GLIB_PREFIX)/lib \
	-L$(CAIRO_PREFIX)/lib \
	-L$(PANGO_PREFIX)/lib \
	-L$(X11_PREFIX)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host="$(FREELINX_TRIPLE)" \
		--prefix="$(PCMANFM_PREFIX)" \
		--disable-desktop-integration \
		--disable-nls \
		--disable-schemas-compile \
		PKG_CONFIG_LIBDIR="$(strip $(PKG_CONFIG_LIBDIR))" \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)"

BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	$(STRIP) "$(PROJECT_BIN)"

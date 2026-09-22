# FreeLinX/ports - archivers/xarchiver : GTK3 graphical archive manager.
#
# xarchiver is a lightweight GTK3 graphical frontend for 7z, zip, tar.gz, bz2, xz.
# Built against GTK3, GLib, Pango, Cairo, and musl. NO GNOME/GNU NLS dependencies.
#
# Configure flags:
#   --enable-gtk3    enable GTK3 interface
#   --disable-nls    disable GNU gettext / NLS

NAME    := xarchiver
VERSION := 0.5.4.23
CATEGORY := archivers
TARGET  := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := graphics/gtk-3.24.52, graphics/glib-2.82.5, \
                graphics/gdk-pixbuf-2.42.12, graphics/cairo, \
                graphics/pango-1.56.4, x11/libX11-1.8.10

BUILD_DEPENDENCIES := pkgconf

INSTALL_BIN    := xarchiver
INSTALL_RELPATH := bin/$(INSTALL_BIN)

XARCH_PREFIX := $(FREELINX_BUILD_DIR)/deps/xarchiver
GTK3_PREFIX  := $(FREELINX_BUILD_DIR)/deps/gtk-3
GLIB_PREFIX  := $(FREELINX_BUILD_DIR)/deps/glib
CAIRO_PREFIX := $(FREELINX_BUILD_DIR)/deps/cairo
PANGO_PREFIX := $(FREELINX_BUILD_DIR)/deps/pango
X11_PREFIX   := $(FREELINX_BUILD_DIR)/deps/x11

PROJECT_BIN := $(XARCH_PREFIX)/bin/xarchiver
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
		--prefix="$(XARCH_PREFIX)" \
		--enable-gtk3 \
		--disable-nls \
		PKG_CONFIG_LIBDIR="$(strip $(PKG_CONFIG_LIBDIR))" \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)"

BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	$(STRIP) "$(PROJECT_BIN)"

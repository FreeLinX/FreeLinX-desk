# FreeLinX/ports - editors/geany : Geany code/text editor (GTK3).
#
# Geany is a fast, lightweight IDE/editor using GTK3 and its own Scintilla-based
# editor component (included in the tarball as a bundled copy of Scintilla/SciTE).
# It has NO GNOME dependency; it only requires GTK3, GLib, and GIO.
#
# Toolchain: clang++ (C++) + LLD + musl + libc++ (LLVM).
# Geany is a C++ project; CXXFLAGS must include -stdlib=libc++ with musl.
#
# Configure flags:
#   --disable-html-docs        no HTML documentation build
#   --disable-pdf-docs         no PDF documentation build
#   --disable-api-docs         no Doxygen API docs
#   --disable-nls              no GNU gettext / NLS (keeps GNU-free)
#   --disable-vte              no VTE terminal widget (reduces GTK deps)
#   --enable-gtk3              use GTK3 (default in Geany 2.x)
#
# No D-Bus, no GNU-specific extensions.  Geany 2.x drops the deprecated
# GDK 2 support, so this targets GTK3 only.

NAME    := geany
VERSION := 2.0
CATEGORY := editors
TARGET  := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := graphics/gtk-3.24.52, graphics/glib-2.82.5, \
                graphics/gdk-pixbuf-2.42.12, graphics/cairo, \
                graphics/pango-1.56.4, x11/libX11-1.8.10

BUILD_DEPENDENCIES := pkgconf

INSTALL_BIN    := geany
INSTALL_RELPATH := bin/$(INSTALL_BIN)

GEANY_PREFIX := $(FREELINX_BUILD_DIR)/deps/geany
GTK3_PREFIX  := $(FREELINX_BUILD_DIR)/deps/gtk-3
GLIB_PREFIX  := $(FREELINX_BUILD_DIR)/deps/glib
CAIRO_PREFIX := $(FREELINX_BUILD_DIR)/deps/cairo
PANGO_PREFIX := $(FREELINX_BUILD_DIR)/deps/pango
X11_PREFIX   := $(FREELINX_BUILD_DIR)/deps/x11

PROJECT_BIN := $(GEANY_PREFIX)/bin/geany
BUILD_BIN   := $(PROJECT_BIN)

# Geany is C++; override FLX defaults for libc++ (LLVM, not libstdc++).
FLX_PROJECT_CXXFLAGS := -O2 -stdlib=libc++ -std=c++17

FLX_PROJECT_CPPFLAGS := \
	-I$(GTK3_PREFIX)/include/gtk-3.0 \
	-I$(GTK3_PREFIX)/include/gdk-3.0 \
	-I$(GLIB_PREFIX)/include/glib-2.0 \
	-I$(GLIB_PREFIX)/lib/glib-2.0/include \
	-I$(GLIB_PREFIX)/include/gio-unix-2.0 \
	-I$(CAIRO_PREFIX)/include/cairo \
	-I$(PANGO_PREFIX)/include/pango-1.0 \
	-I$(X11_PREFIX)/include

FLX_PROJECT_LDFLAGS := \
	-L$(GTK3_PREFIX)/lib \
	-L$(GLIB_PREFIX)/lib \
	-L$(CAIRO_PREFIX)/lib \
	-L$(PANGO_PREFIX)/lib \
	-L$(X11_PREFIX)/lib

# musl libc++/libc++abi/libunwind static closure for C++ link.
FLX_PROJECT_LIBS := \
	-L$(FREELINX_TOOLCHAIN_DIR)/lib/$(FREELINX_TRIPLE) \
	-lc++ -lc++abi -lunwind

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host="$(FREELINX_TRIPLE)" \
		--prefix="$(GEANY_PREFIX)" \
		--disable-html-docs \
		--disable-pdf-docs \
		--disable-api-docs \
		--disable-nls \
		--disable-vte \
		--enable-gtk3 \
		PKG_CONFIG_LIBDIR="$(strip $(PKG_CONFIG_LIBDIR))" \
		CC="$(CC)" \
		CXX="$(CXX)" \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)"

BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	$(STRIP) "$(PROJECT_BIN)"

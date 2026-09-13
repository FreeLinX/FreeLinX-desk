# FreeLinX/ports - x11/openbox-3.6.1 : standard-compliant X11 stacking WM.
#
# OpenBox is a lightweight, standards-compliant X11 window manager.  It links
# statically against the FreeLinX musl+clang toolchain and the shared X11 dep
# tree (libX11, libxml2, glib, pangoxft-compat).  No GNU runtime dependencies.
#
# Configured with standard prefix=/usr and sysconfdir=/etc so that no build host
# paths are baked into the binary.
#
# Dependencies (all built into deps/x11 or deps/glib-*):
#   libX11, libXau, libXdmcp, libxcb, libXext, libXcursor, libXfixes,
#   libXinerama, libXrandr, libXrender, libxml2, glib-2.0,
#   pangoxft (FreeLinX compat shim), pangocairo, cairo, cairo-xlib, xft

NAME    := openbox-3.6.1
VERSION := 3.6.1
CATEGORY:= x11
LICENSE := GPL-2.0-or-later

FLX_PREFIX  = $(FREELINX_BUILD_DIR)/deps/$(NAME)
SRC_TREE    = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN = $(FLX_PREFIX)/usr/bin/openbox
BUILD_BIN   = $(PROJECT_BIN)
INSTALL_RELPATH := usr/bin/openbox

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS:=

include ../../mk/project-port.mk

# --- dependency paths -------------------------------------------------------

# Static X11 libraries and headers live in the shared deps/x11 tree.
export LDFLAGS  := -L$(FREELINX_BUILD_DIR)/deps/x11/lib $(LDFLAGS)
export CFLAGS   := -I$(FREELINX_BUILD_DIR)/deps/x11/include $(CFLAGS)
export CPPFLAGS := -I$(FREELINX_BUILD_DIR)/deps/x11/include $(CPPFLAGS)

# pkg-config with --static so transitive deps (xft, cairo-xlib, pangocairo,
# pango, glib, ...) resolve correctly through the shared PKG_CONFIG_LIBDIR.
export PKG_CONFIG := /usr/bin/pkg-config --static

# glib-mkenums (code generator) must be on PATH during build.
export PATH := $(FREELINX_BUILD_DIR)/deps/glib-2.82.5/bin:$(PATH)

# Static libX11 pulls in Xau, Xdmcp, and xcb; bare `-lX11` configure probes
# need these on the link line explicitly.
export LIBS := -lXau -lXdmcp -lxcb -lpthread -lm

# --- build phases -----------------------------------------------------------

# OpenBox ships autotools.  config.sub/config.guess are needed for the
# cross-compile triple; we copy them from the host automake installation.
# Configured for native /usr prefix and /etc sysconfdir.
PROJECT_CFG_CMDS = \
	cp /usr/share/automake-1.16/config.sub ./config.sub && \
	cp /usr/share/automake-1.16/config.guess ./config.guess && \
	./configure \
		--host=x86_64-linux-musl \
		--prefix=/usr \
		--sysconfdir=/etc \
		--mandir=/usr/share/man \
		--localstatedir=/var \
		--disable-shared --enable-static \
		--disable-dependency-tracking \
		--disable-pyconify \
		--disable-dbus \
		--disable-startup-notification \
		--disable-session-management \
		--disable-imlib2

BUILD_CMDS = make && make DESTDIR="$(FLX_PREFIX)" install && \
	mkdir -p "$(FLX_PREFIX)/bin" && \
	ln -sfn ../usr/bin/openbox "$(FLX_PREFIX)/bin/openbox"

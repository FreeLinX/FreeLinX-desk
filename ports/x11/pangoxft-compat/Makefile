# FreeLinX/ports - x11/pangoxft-compat : pangoxft API over PangoCairo/cairo-xlib.
# Modern Pango dropped the pangoxft module; Openbox 3.6.1 still links it.
NAME:=pangoxft-compat
CATEGORY:=x11
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
DISTINFO_NAME:=.
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN=$(FLX_PREFIX)/lib/libpangoxft.a
BUILD_BIN=$(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS?=

include ../../mk/project-port.mk

export PKG_CONFIG:=/usr/bin/pkg-config --static

PROJECT_CFG_CMDS = :

BUILD_CMDS = \
	mkdir -p "$(FREELINX_BUILD_DIR)/obj/$(NAME)" \
		"$(FLX_PREFIX)/lib" "$(FLX_PREFIX)/lib/pkgconfig" \
		"$(FLX_PREFIX)/include/pango" && \
	FLX_INC="$$($(PKG_CONFIG) --cflags pango cairo-xlib xft)" && \
	$(CC) $(CPPFLAGS) $(CFLAGS) $$FLX_INC \
		-c -o "$(FREELINX_BUILD_DIR)/obj/$(NAME)/pangoxft.o" pangoxft.c && \
	$(AR) rcs "$(FLX_PREFIX)/lib/libpangoxft.a" \
		"$(FREELINX_BUILD_DIR)/obj/$(NAME)/pangoxft.o" && \
	cp pangoxft.h "$(FLX_PREFIX)/include/pango/pangoxft.h" && \
	cp pangoxft.pc "$(FLX_PREFIX)/lib/pkgconfig/pangoxft.pc"
NAME := xfe
VERSION := 1.46.1
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := x11/fox, x11/libX11-1.8.10, graphics/freetype

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	PATH="/tmp/intltool-bin:$$PATH" \
	PKG_CONFIG_PATH="$(FREELINX_SYSROOT)/lib/pkgconfig" \
	FREETYPE_CFLAGS="-I$(FREELINX_SYSROOT)/include/freetype2" \
	FREETYPE_LIBS="-L$(FREELINX_SYSROOT)/lib -lfreetype" \
	XFT_CFLAGS="-I$(FREELINX_SYSROOT)/include" \
	XFT_LIBS="-L$(FREELINX_SYSROOT)/lib -lXft" \
	FOX_CONFIG=$(FREELINX_BUILD_DIR)/deps/fox/bin/fox-config \
	CXXFLAGS="$(CXXFLAGS) -I$(FREELINX_BUILD_DIR)/deps/fox/include -I$(FREELINX_BUILD_DIR)/deps/fox/include/fox-1.6 -DHAVE_XFT_H -DHAVE_XRANDR_H=1 -DHAVE_PNG_H=1" \
	CPPFLAGS="$(CXXFLAGS) -I$(FREELINX_BUILD_DIR)/deps/fox/include -I$(FREELINX_BUILD_DIR)/deps/fox/include/fox-1.6 -DHAVE_XFT_H -DHAVE_PNG_H=1" \
	LDFLAGS="$(LDFLAGS) -L$(FREELINX_BUILD_DIR)/deps/fox/lib -Wl,--allow-multiple-definition" \
	LIBS="$$($(FREELINX_BUILD_DIR)/deps/fox/bin/fox-config --libs) -lxcb -lXau -lXdmcp -lexpat -lpng -lz" \
	./configure \
		--host=$(TARGET) \
		--prefix=$(FREELINX_STAGING_ROOT)/usr \
		--enable-static \
		--disable-shared \
		--disable-sn \
		--disable-nls

# The command-line CXXFLAGS override on make drops config-derived includes;
# re-add the FOX headers dir explicitly so fx.h is found.
BUILD_CMDS = \
	make -j$$(nproc) CXXFLAGS="$(CXXFLAGS) -I$(FREELINX_BUILD_DIR)/deps/fox/include -I$(FREELINX_BUILD_DIR)/deps/fox/include/fox-1.6 -DHAVE_XFT_H -DHAVE_XRANDR_H=1 -DHAVE_PNG_H=1 -Wl,--allow-multiple-definition" LDFLAGS="$(LDFLAGS) -L$(FREELINX_BUILD_DIR)/deps/fox/lib -Wl,--allow-multiple-definition" && \
	make install

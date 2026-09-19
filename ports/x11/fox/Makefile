NAME := fox
VERSION := 1.6.57
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := LGPL-2.1
DEPENDENCIES := x11/libX11-1.8.10, x11/libXext-1.3.6, x11/libXcursor-1.2.2, x11/libXrandr-1.5.4, x11/libXft-2.3.8

include ../../mk/project-port.mk

FOX_PREFIX = $(FREELINX_BUILD_DIR)/deps/fox

PROJECT_CFG_CMDS = \
	CXXFLAGS="$(CXXFLAGS) -Wno-register" \
	./configure \
		--host=$(TARGET) \
		--prefix=$(FOX_PREFIX) \
		--enable-static \
		--disable-shared \
		--disable-jpeg \
		--disable-tiff \
		--disable-bz2lib \
		--with-x \
		--x-includes=/home/devuan/FreeLinX/Desktop-test/toolchain/x86_64-linux-musl/include \
		--x-libraries=/home/devuan/FreeLinX/Desktop-test/toolchain/x86_64-linux-musl/lib \
		--with-xft \
		--with-opengl=no \
		--with-xinput=no \
		LIBS="-lpng -lz -lxcb -lXau -lXdmcp"

# The configure run appends -DHAVE_* feature switches to CXXFLAGS, but a
# command-line CXXFLAGS override on make silently discards them.  Re-add the
# switches configure enables with --with-xft so the Xft/fontconfig font path is
# compiled in (otherwise FXFont falls back to XLFD core fonts and renders 1px),
# and -DHAVE_PNG_H=1 so PNG icons in Xfe render properly.
BUILD_CMDS = \
	make -j$$(nproc) CXXFLAGS="$(CXXFLAGS) -DUNICODE -DHAVE_ZLIB_H=1 -DHAVE_XFT_H=1 -DHAVE_PNG_H=1 -I$(FREELINX_SYSROOT)/include/freetype2 -DHAVE_XSHM_H=1 -DHAVE_XSHAPE_H=1 -DHAVE_XCURSOR_H=1 -DHAVE_XRENDER_H=1 -DHAVE_XRANDR_H=1 -DHAVE_XFIXES_H=1 -DNO_XIM -Wno-register" X_BASE_LIBS="-lX11 -lXext -lfreetype -lfontconfig -lXft -lXcursor -lXrender -lXrandr -lXfixes -lpng -lz -lxcb -lXau -lXdmcp" && \
	make install

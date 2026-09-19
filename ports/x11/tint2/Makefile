NAME := tint2
VERSION := v17.0.2
CATEGORY := x11
TARGET := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := x11/libX11-1.8.10, x11/libXext-1.3.6, x11/libXrandr-1.5.4, x11/libXinerama-1.1.5, x11/libXfixes-6.0.1, x11/libXcomposite-0.4.6, x11/libXdamage-1.1.6, x11/libXrender-0.9.11, graphics/cairo, x11/pango-1.56.4, x11/glib-2.82.5, graphics/imlib2

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	mkdir -p build && cd build && \
	PKG_CONFIG_LIBDIR="/home/devuan/FreeLinX/Desktop-test/toolchain/x86_64-linux-musl/lib/pkgconfig:/home/devuan/FreeLinX/Desktop-test/toolchain/x86_64-linux-musl/share/pkgconfig" \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=$(FREELINX_STAGING_ROOT)/usr \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_C_FLAGS="$(CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(CXXFLAGS)" \
		-DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS)" \
		-DENABLE_EXAMPLES=OFF \
		-DENABLE_TINT2CONF=OFF \
		-DENABLE_BATTERY=ON

BUILD_CMDS = \
	cd build && \
	make && \
	make install

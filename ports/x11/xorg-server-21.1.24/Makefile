# FreeLinX/ports - x11/xorg-server-21.1.24 : Xorg X server (fbdev + KMS/DRI, static).
NAME:=xorg-server-21.1.24
CATEGORY:=x11
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN=$(FLX_PREFIX)/bin/Xorg
BUILD_BIN=$(PROJECT_BIN)

# Pure-C stack: drop the default C++/unwind link closure.
FLX_PROJECT_LIBS?=

# -I for <sha1.h>: the SHA1 implementation comes from base/libmd (built into
# build/deps/libmd); os/xsha1.c includes it directly under
# HAVE_SHA1_IN_LIBMD.  Defined before the include so the exported
# CPPFLAGS/CFLAGS pick it up.
#
# -I for <drm/drm.h>: DRI2/DRI3 (and therefore the modesetting DDX) needs
# libdrm, which lives in the build-time dep prefix rather than the sysroot.
# graphics/libdrm is built as a static archive; PKG_CONFIG_LIBDIR is aggregated
# from deps/*/lib/pkgconfig by mk/pkgconfig-libdir.mk, so configure finds it.
FLX_PROJECT_CPPFLAGS=-I$(FREELINX_BUILD_DIR)/deps/libmd/include -I$(FREELINX_BUILD_DIR)/deps/libdrm/include -I$(FREELINX_BUILD_DIR)/deps/libdrm/include/libdrm -I$(FREELINX_BUILD_DIR)/deps/x11/include

include ../../mk/project-port.mk

# Xorg must stay a dynamic (PIE) executable so the dlopen'd driver modules
# (fbdev, modesetting, input) can resolve their symbols against the running
# server.  Its library deps are all static .a's; only musl libc remains dynamic.
# -L for configure's AC_CHECK_LIB([md],[SHA1Init]) link probe, and for the
# static libdrm that DRI2/DRI3 is compiled and linked against.
export LDFLAGS:=$(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) --rtlib=compiler-rt -fuse-ld=lld -Wl,--export-dynamic -L$(FREELINX_BUILD_DIR)/deps/libmd/lib -L$(FREELINX_BUILD_DIR)/deps/libdrm/lib -L$(FREELINX_BUILD_DIR)/deps/x11/lib

# --- DRI support ----------------------------------------------------------
# DRI2/DRI3/Present are what the modesetting DDX needs for native KMS mode
# setting, hardware vblank and page-flip.  They depend on libdrm + xshmfence
# (graphics/libdrm, x11/libxshmfence) and on header-only protos that
# x11/xorgproto ships all of, so none of them pull in a client-side X library.
#
# `--disable-dri` is deliberate: that is the legacy XF86DRI 1/2 interface, and
# configure adds `dri >= 7.8.0` (libdri) to REQUIRED_MODULES when it is on
# (configure.ac:1093).  libdri was dropped from libdrm in 2.4, so enabling it
# would need a library that no longer exists.  Nothing in a KMS desktop needs it.
#
# `--disable-glx` is equally deliberate: configure only then skips the
# `PKG_CHECK_MODULES([XLIB],[x11])` at configure.ac:1236 that would require the
# whole libX11/libxcb client stack plus Mesa.  OpenGL is a separate follow-up
# (libX11 stack + Mesa/EGL/GBM); it is not needed to get hardware mode setting.

PROJECT_CFG_CMDS = \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(FLX_PREFIX)" \
		--disable-shared --enable-static \
		--disable-dependency-tracking \
		--disable-xvfb --disable-xnest --disable-xquartz --disable-xwin \
		--disable-kdrive --disable-xephyr \
		--disable-dri \
		--enable-dri2 --enable-dri3 \
		--enable-present --enable-glxext --enable-xext \
		--disable-glx \
		--disable-glamor \
		--enable-xinerama --disable-xvmc \
		--disable-xorg-docs --disable-devel-docs \
		--disable-config-udev --disable-config-udev-kms --disable-config-hal \
		--disable-linux-acpi --disable-linux-apm \
		--disable-libunwind --disable-unit-tests \
		--with-xkb-bin-directory=/usr/bin \
		--with-xkb-path=/usr/share/X11/xkb \
		--with-xkb-output="$(FLX_PREFIX)/var/lib/xkb" \
		--with-default-xkb-rules=base \
		--with-default-xkb-model=pc105 \
		--with-default-xkb-layout=us \
		--with-sha1=libmd \


BUILD_CMDS = make && make install
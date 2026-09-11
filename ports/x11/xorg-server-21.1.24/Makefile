# FreeLinX/ports - x11/xorg-server-21.1.24 : Xorg X server (fbdev, static).
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

include ../../mk/project-port.mk

# Xorg must stay a dynamic (PIE) executable so the dlopen'd driver modules
# (fbdev, input) can resolve their symbols against the running server.  Its
# library deps are all static .a's; only musl libc remains dynamic.
export LDFLAGS:=$(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) --rtlib=compiler-rt -fuse-ld=lld -Wl,--export-dynamic

export PKG_CONFIG:=/usr/bin/pkg-config --static

PROJECT_CFG_CMDS = \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(FLX_PREFIX)" \
		--disable-shared --enable-static \
		--disable-dependency-tracking \
		--disable-xvfb --disable-xnest --disable-xquartz --disable-xwin \
		--disable-kdrive --disable-xephyr \
		--disable-dri --disable-dri2 --disable-dri3 --disable-glx \
		--disable-glamor \
		--disable-xinerama --disable-xvmc \
		--disable-xorg-docs --disable-devel-docs \
		--disable-config-udev --disable-config-udev-kms --disable-config-hal \
		--disable-linux-acpi --disable-linux-apm \
		--disable-libunwind --disable-unit-tests \
		--with-xkb-bin-directory="$(FLX_PREFIX)/bin" \
		--with-xkb-path=/usr/share/X11/xkb \
		--with-xkb-output="$(FLX_PREFIX)/var/lib/xkb" \
		--with-default-xkb-rules=base \
		--with-default-xkb-model=pc105 \
		--with-default-xkb-layout=us \
		--with-sha1=libmd \


BUILD_CMDS = make && make install
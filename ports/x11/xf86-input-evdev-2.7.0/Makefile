# FreeLinX/ports - x11/xf86-input-evdev-2.7.0 : evdev input driver module.
#
# Loadable Xorg input driver that talks raw evdev to /dev/input/eventN.  The
# FreeLinX image binds it to /dev/fl-kbd and /dev/fl-pointer (symlinks to the
# QEMU PS/2 keyboard and mouse nodes) via xorg.conf.
#
# Like xf86-video-fbdev, libtool drops the --target/-fuse-ld flags on the
# module relink, so the driver is compiled and linked directly with the
# toolchain clang; Xorg's symbols stay undefined (resolved at dlopen time).
NAME:=xf86-input-evdev-2.7.0
CATEGORY:=x11
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=MIT-X11

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(NAME)
PROJECT_BIN=$(FLX_PREFIX)/lib/xorg/modules/input/evdev_drv.so
BUILD_BIN=$(PROJECT_BIN)

FLX_PROJECT_LIBS?=

include ../../mk/project-port.mk

export PKG_CONFIG:=/usr/bin/pkg-config --static

PROJECT_CFG_CMDS = \
	cp /usr/share/automake-1.16/config.sub ./config.sub && \
	cp /usr/share/automake-1.16/config.guess ./config.guess && \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(FLX_PREFIX)" \
		--disable-dependency-tracking

BUILD_CMDS = \
	mkdir -p "$(FLX_PREFIX)/lib/xorg/modules/input" && \
	$(CC) $(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) \
		-fuse-ld=lld --rtlib=compiler-rt -O2 -shared -fPIC \
		-Wno-incompatible-function-pointer-types -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers \
		-DHAVE_CONFIG_H \
		-I"$(SRC_TREE)" -I"$(SRC_TREE)/src" -I"$(SRC_TREE)/include" \
		-I"$(FLX_PREFIX)/include/xorg" \
		-I"$(FLX_PREFIX)/include" \
		-I"$(FREELINX_BUILD_DIR)/deps/pixman/include/pixman-1" \
		-o "$(PROJECT_BIN)" \
		"$(SRC_TREE)/src/evdev.c" \
		"$(SRC_TREE)/src/apple.c" \
		"$(SRC_TREE)/src/draglock.c" \
		"$(SRC_TREE)/src/emuMB.c" \
		"$(SRC_TREE)/src/emuThird.c" \
		"$(SRC_TREE)/src/emuWheel.c"
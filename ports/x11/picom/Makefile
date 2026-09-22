# FreeLinX/ports - x11/picom : X compositor (screen tearing fix, shadows,
# transparency).  Built with meson/ninja against the FreeLinX LLVM+musl
# toolchain.  No GNU libc required.
#
# Animation support is intentionally DISABLED (--animations=false at runtime;
# built without any animation backend).  picom v11 uses a "picom.conf" at
# ~/.config/picom.conf; FreeLinX ships a minimal one via the rootfs overlay.
#
# Build deps (all from FreeLinX ports):
#   libX11, libXext, libXrender, libXfixes, libXdamage, libXcomposite,
#   libXrandr, libxcb, xcb-util, libGL (Mesa), libev, libconfig, pcre2,
#   dbus (optional, disabled), pixman, uthash (header-only).
#
# picom uses meson; we pass -Dwith_docs=false and -Dwith_animations=false.
# OpenGL backend is enabled (needed for vsync / tear-free rendering).

NAME    := picom
VERSION := v11.2
CATEGORY := x11
TARGET  := $(FREELINX_TRIPLE)
LICENSE := MIT
DEPENDENCIES := x11/libX11-1.8.10, x11/libXext-1.3.6, x11/libXrender-0.9.11, \
                x11/libXfixes-6.0.1, x11/libxcb-1.17.0, graphics/pixman, \
                graphics/pcre2-10.48, graphics/libdrm

BUILD_DEPENDENCIES := meson, ninja, pkgconf, uthash

INSTALL_BIN   := picom
INSTALL_RELPATH := bin/$(INSTALL_BIN)

PICOM_PREFIX := $(FREELINX_BUILD_DIR)/deps/picom

PROJECT_BIN := $(PICOM_PREFIX)/bin/picom
BUILD_BIN   := $(PROJECT_BIN)

include ../../mk/project-port.mk

# picom needs libev (header-only API exposed as a shared dep); we use the
# bundled uthash.  libconfig is the only non-trivial extra dep; picom v11
# ships a fallback config reader when libconfig is absent (--without-libconfig
# is no longer a meson option but omitting it from PKG_CONFIG path suffices).
FLX_PROJECT_CPPFLAGS := \
	-I$(FREELINX_BUILD_DIR)/deps/pcre2/include \
	-I$(FREELINX_BUILD_DIR)/deps/pixman/include/pixman-1 \
	-I$(FREELINX_BUILD_DIR)/deps/x11/include

FLX_PROJECT_LDFLAGS := \
	-L$(FREELINX_BUILD_DIR)/deps/pcre2/lib \
	-L$(FREELINX_BUILD_DIR)/deps/pixman/lib \
	-L$(FREELINX_BUILD_DIR)/deps/x11/lib

# meson cross-compile file path (generated in do-config)
MESON_CROSS := $(FREELINX_BUILD_DIR)/obj/picom-cross.ini
MESON_BUILD := $(FREELINX_BUILD_DIR)/obj/picom-build

PROJECT_CFG_CMDS = \
	mkdir -p "$(MESON_BUILD)" && \
	printf '[binaries]\nc = "%s"\ncpp = "%s"\nar = "%s"\nstrip = "%s"\npkgconfig = "pkg-config"\n[host_machine]\nsystem = "linux"\ncpu_family = "x86_64"\ncpu = "x86_64"\nendian = "little"\n' \
		"$(CC)" "$(CXX)" "$(AR)" "$(STRIP)" > "$(MESON_CROSS)" && \
	PKG_CONFIG_LIBDIR="$(strip $(PKG_CONFIG_LIBDIR))" \
	meson setup "$(MESON_BUILD)" "$(SRC_TREE)" \
		--cross-file="$(MESON_CROSS)" \
		--prefix="$(PICOM_PREFIX)" \
		--buildtype=release \
		-Dwith_docs=false \
		-Dlegacy_backends=false \
		-Db_staticpic=false \
		-Dxinerama=false \
		-Dregex=false \
		-Dmodules=false 2>&1 | head -60

BUILD_CMDS = \
	ninja -C "$(MESON_BUILD)" $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	ninja -C "$(MESON_BUILD)" install && \
	$(STRIP) "$(PROJECT_BIN)"

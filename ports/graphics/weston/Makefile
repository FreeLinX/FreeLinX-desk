# FreeLinX/ports - graphics/weston : Weston 13.0.1 Wayland compositor.
#
# Reference Wayland compositor.  Built from official upstream, cross-built
# static-ish with the FreeLinX musl toolchain.  The DRM (KMS/virtio-gpu)
# backend plus the headless backend are enabled; the compositor runs with the
# pixman renderer (no GL).  Keyboard, seat (libseat builtin backend) and
# libinput input are wired in.  X11/wayland/rdp/vnc/pipewire backends,
# xwayland, GL renderer, colord/lcms, jpeg/webp and demo clients are all
# disabled for a lean headless-to-DRM compositor.

NAME   := weston
VERSION:= 13.0.1
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl, wayland, wayland-protocols, pixman, libinput, libevdev, libseat, libdrm, libxkbcommon, libudev-zero, cairo, fontconfig, freetype, expat, libpng, zlib
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

WESTON_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=weston
INSTALL_RELPATH:= bin/weston

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS := /tmp/opencode/host-tools
MESON    := /home/devuan/.local/venvs/meson/bin/meson
DEPS     := $(FREELINX_BUILD_DIR)/deps
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/weston-$(VERSION)-fad928ca37beb3bdf70f33bcfcb12149e4da217d
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson

export PATH := $(HOST_TOOLS):$(PATH)

DEV_PC := /tmp/opencode/host-wl/lib/pkgconfig

# pkg-config lookup: target deps first, then host tools (wayland-scanner).
DEPS_PKGCONFIG := \
	$(DEPS)/wayland/lib/pkgconfig:$(DEPS)/pixman/lib/pkgconfig: \
	$(DEPS)/libinput/lib/pkgconfig:$(DEPS)/libevdev/lib/pkgconfig: \
	$(DEPS)/libseat/lib/pkgconfig:$(DEPS)/libdrm/lib/pkgconfig: \
	$(DEPS)/libxkbcommon/lib/pkgconfig:$(DEPS)/libudev-zero/lib/pkgconfig: \
	$(DEPS)/libffi/lib/pkgconfig:$(DEPS)/wayland-protocols/share/pkgconfig

export PKG_CONFIG_PATH := $(DEV_PC):$(DEPS_PKGCONFIG)

PROJECT_CFG_CMDS = \
	python3 "$(PORT_DIR)/musl-patches.py" "$(SRC_TREE)" && \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--native-file "$(PORT_DIR)/meson-native.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="/usr" \
		-Dbackend-drm=true -Dbackend-headless=true \
		-Dbackend-drm-screencast-vaapi=false \
		-Dbackend-pipewire=false -Dbackend-rdp=false -Dbackend-vnc=false \
		-Dbackend-wayland=false -Dbackend-x11=false -Dscreenshare=false \
		-Dbackend-default=drm \
		-Drenderer-gl=false -Dxwayland=false -Dsystemd=false \
		-Dremoting=false -Dpipewire=false \
		-Dshell-desktop=true -Dshell-kiosk=true \
		-Dshell-fullscreen=false -Dshell-ivi=false \
		-Dcolor-management-lcms=false -Dimage-jpeg=false -Dimage-webp=false \
		-Dtools=[] -Ddemo-clients=false -Dsimple-clients=[] \
		-Dtest-junit-xml=false -Ddoc=false \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	DESTDIR="$(WESTON_PREFIX)" "$(MESON)" install -C "$(BUILD_DIR)"

# weston installs under --prefix=/usr; the install root is DESTDIR=$WESTON_PREFIX,
# so the resulting tree mirrors a target rootfs: $(WESTON_PREFIX)/usr/...
PROJECT_BIN = $(WESTON_PREFIX)/usr/bin/weston
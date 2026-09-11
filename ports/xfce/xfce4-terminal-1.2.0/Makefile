# FreeLinX/ports - xfce/xfce4-terminal-1.2.0 : Xfce terminal emulator (Wayland, static).
NAME:=xfce4-terminal-1.2.0
CATEGORY:=xfce
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=GPL-2.0-or-later

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON:=/home/devuan/.local/venvs/meson/bin/meson
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR=$(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN=$(FLX_PREFIX)/bin/xfce4-terminal
BUILD_BIN=$(PROJECT_BIN)

# musl lacks __cxa_thread_atexit_impl (glibc ext needed by libc++abi); shim.
FLX_PROJECT_LIBS?=-L$(FLX_PROJECT_LIBDIR) -lc++ -lc++abi -lunwind -lflx_cxa

include ../../mk/project-port.mk

export PATH := /home/devuan/FreeLinX/desktop-test/.venv/bin:$(FREELINX_BUILD_DIR)/deps/glib-2.82.5/bin:$(PATH)

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dx11=disabled -Dwayland=enabled \
		-Dgtk-layer-shell=disabled -Dlibutempter=disabled \
		-Ddoc=false \
		--prefix="$(FLX_PREFIX)" \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
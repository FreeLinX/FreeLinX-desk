# FreeLinX/ports - system/dbus-1.16.2 : D-Bus message bus daemon + libdbus.
# Meson static cross build. Session bus runs root in the single-user guest.
NAME:=dbus-1.16.2
CATEGORY:=system
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=AFL-2.1

FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/$(NAME)
MESON:=/home/devuan/.local/venvs/meson/bin/meson
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
BUILD_DIR=$(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN=$(FLX_PREFIX)/bin/dbus-daemon
BUILD_BIN=$(PROJECT_BIN)

include ../../mk/project-port.mk

export PATH := /home/devuan/FreeLinX/desktop-test/.venv/bin:$(PATH)

PROJECT_CFG_CMDS = \
	rm -rf "$(BUILD_DIR)" && mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(CURDIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		-Dapparmor=disabled -Dlaunchd=disabled -Dlibaudit=disabled \
		-Dselinux=disabled -Dsystemd=disabled -Duser_session=false \
		-Dx11_autolaunch=disabled -Dtraditional_activation=false \
		-Dxml_docs=disabled -Ddoxygen_docs=disabled -Dducktype_docs=disabled \
		-Dqt_help=disabled -Dmodular_tests=disabled -Dinstalled_tests=false \
		-Dintrusive_tests=false -Ddbus_user=root \
		--prefix=/usr \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	DESTDIR="$(FLX_PREFIX)" "$(MESON)" install -C "$(BUILD_DIR)"
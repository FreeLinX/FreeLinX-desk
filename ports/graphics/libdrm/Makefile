# FreeLinX/ports - graphics/libdrm : libdrm 2.4.123 (build dependency).
#
# Direct Rendering Manager user-space library: kernel DRM ioctl wrappers,
# KMS helpers and the libkms + device-node plumbing needed by Mesa, Xorg and
# KMS/DRM compositors.  Built static against the FreeLinX musl sysroot with
# the FreeLinX clang+LLD toolchain via a meson cross build.  Installed only
# into the build-time dependency prefix (build/deps/libdrm); consumers link
# the static archive.
#
# Driver backends are enabled in the kernel (virtio-gpu + i915); the user-
# space side here is the core library only (no driver helper shims), which is
# all that compositors and Mesa use.

NAME   := libdrm
VERSION:= 2.4.123
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

# Build-time dependency prefix consumed by the graphics stack.
DRM_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

# Static archive only; not staged into the rootfs.
INSTALL_BIN:=
INSTALL_RELPATH:= lib/libdrm.a

include ../../mk/project-port.mk

PORT_DIR := $(CURDIR)
HOST_TOOLS ?= $(FREELINX_HOST_TOOLS)
MESON ?= $(FREELINX_MESON)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libdrm-$(VERSION)
BUILD_DIR = $(FREELINX_BUILD_DIR)/obj/$(NAME)/meson
PROJECT_BIN = $(DRM_PREFIX)/lib/libdrm.a

# meson needs ninja on PATH for the target build.
export PATH := $(HOST_TOOLS):$(PATH)

PROJECT_CFG_CMDS = \
	mkdir -p "$(BUILD_DIR)" && \
	"$(MESON)" setup \
		--cross-file "$(PORT_DIR)/meson-cross.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix="$(DRM_PREFIX)" \
		-Dman-pages=disabled -Dcairo-tests=disabled -Dvalgrind=disabled \
		-Dtests=false -Dinstall-test-programs=false \
		-Dintel=disabled -Dradeon=disabled -Damdgpu=disabled \
		-Dnouveau=disabled -Domap=disabled -Dexynos=disabled -Dtegra=disabled \
		-Dvc4=disabled -Detnaviv=disabled -Dfreedreno=disabled \
		-Dvmwgfx=disabled \
		"$(BUILD_DIR)" "$(SRC_TREE)"

BUILD_CMDS = \
	"$(MESON)" compile -C "$(BUILD_DIR)" && \
	"$(MESON)" install -C "$(BUILD_DIR)"
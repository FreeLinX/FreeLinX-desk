# FreeLinX/ports - graphics/mtdev : mtdev 1.1.6 (build dependency).
#
# Kernel Multitouch Protocol A/B translation library, required by libinput
# for touchscreen devices.  Cross-built (autotools) static against the
# FreeLinX musl sysroot; installed only into build/deps/mtdev.

NAME   := mtdev
VERSION:= 1.1.6
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

MTDEV_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libmtdev.a

include ../../mk/project-port.mk

COMMON_FLAGS = $(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) --rtlib=compiler-rt -fuse-ld=lld
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/mtdev-$(VERSION)
PROJECT_BIN = $(MTDEV_PREFIX)/lib/libmtdev.a

FLX_HOST_AR   ?= /home/devuan/FreeLinX/toolchain/bin/llvm-ar
FLX_HOST_RANLIB ?= /home/devuan/FreeLinX/toolchain/bin/llvm-ranlib

export CC := $(FREELINX_TOOLCHAIN_BIN)/freelinix-cc
export AR := $(FLX_HOST_AR)
export RANLIB := $(FLX_HOST_RANLIB)

PROJECT_CFG_CMDS = \
	(cd "$(SRC_TREE)" && \
		./configure --host=x86_64-linux-gnu \
			--build=x86_64-pc-linux-gnu \
			--disable-shared --enable-static \
			--prefix="$(MTDEV_PREFIX)" \
			CFLAGS="$(COMMON_FLAGS) -O2" \
			LDFLAGS="$(COMMON_FLAGS)" \
			CC="$(FREELINX_TOOLCHAIN_BIN)/freelinix-cc" \
			AR="$(FLX_HOST_AR)" RANLIB="$(FLX_HOST_RANLIB)")

BUILD_CMDS = \
	$(MAKE) -C "$(SRC_TREE)" -j"$(FREELINX_JOBS)" && \
	$(MAKE) -C "$(SRC_TREE)" install
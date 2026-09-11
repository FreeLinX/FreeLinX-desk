# FreeLinX/ports - graphics/libffi : libffi 3.4.6 (build dependency).
#
# Foreign Function Interface library, required by Wayland (libwayland uses
# libffi closures).  Cross-built with autotools against the FreeLinX musl
# sysroot; installed only into build/deps/libffi.  The FreeLinX clang wrapper
# provides the target compiler; configure runs its host-side feature checks
# with --build set to the real host so cross detection works.

NAME   := libffi
VERSION:= 3.4.6
CATEGORY:= graphics
LICENSE:= MIT
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

FFI_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

INSTALL_BIN:=
INSTALL_RELPATH:= lib/libffi.a

include ../../mk/project-port.mk

COMMON_FLAGS = $(FREELINX_TARGET_FLAGS) $(FREELINX_SYSROOT_FLAGS) --rtlib=compiler-rt -fuse-ld=lld
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/libffi-$(VERSION)
PROJECT_BIN = $(FFI_PREFIX)/lib/libffi.a

FLX_HOST_AR   ?= /home/devuan/FreeLinX/toolchain/bin/llvm-ar
FLX_HOST_RANLIB ?= /home/devuan/FreeLinX/toolchain/bin/llvm-ranlib

export CC := $(FREELINX_TOOLCHAIN_BIN)/freelinix-cc
export AR := $(FLX_HOST_AR)
export RANLIB := $(FLX_HOST_RANLIB)

PROJECT_CFG_CMDS = \
	(cd "$(SRC_TREE)" && \
		./configure --host=x86_64-linux-musl \
			--build=x86_64-pc-linux-gnu \
			--disable-shared --enable-static \
			--prefix="$(FFI_PREFIX)" \
			CFLAGS="$(COMMON_FLAGS) -O2" \
			LDFLAGS="$(COMMON_FLAGS)" \
			CC="$(FREELINX_TOOLCHAIN_BIN)/freelinix-cc" \
			AR="$(FLX_HOST_AR)" RANLIB="$(FLX_HOST_RANLIB)")

BUILD_CMDS = \
	$(MAKE) -C "$(SRC_TREE)" -j"$(FREELINX_JOBS)" && \
	$(MAKE) -C "$(SRC_TREE)" install
# FreeLinX/ports - base/libmd : libmd 1.2.0 (build dependency, upstream).
#
# Real upstream libmd (BSD message digest functions) built with the FreeLinX
# clang + LLD + musl toolchain, statically (libmd.a).  It is a build-time
# dependency for xorg-server (--with-sha1=libmd) and is installed only into
# the build-time dependency prefix (build/deps/libmd); it is intentionally
# NOT staged into the rootfs, since it is linked statically into its
# consumers.  libmd supplies the SHA1Init/SHA1Update/SHA1Final + SHA1_CTX
# API that Xorg's os/xsha1.c expects under HAVE_SHA1_IN_LIBMD.  No GNU
# runtime dependency.

NAME   := libmd
VERSION:= 1.2.0
CATEGORY:= base
LICENSE:= BSD-3-Clause AND BSD-2-Clause AND ISC AND Beerware AND Public Domain
DEPENDENCIES:=
BUILD_DEPENDENCIES:= musl (via FreeLinX toolchain sysroot)
TARGET := $(FREELINX_TRIPLE)
PREFIX := /

# Build-time dependency prefix (xorg-server consumes it via -L/-I).
LIBMD_PREFIX = $(FREELINX_BUILD_DIR)/deps/libmd

# libmd is C; do NOT pull in the C++/libc++ link libraries.
FLX_PROJECT_LIBS :=
FLX_PROJECT_CPPFLAGS =
FLX_PROJECT_LDFLAGS  =

DISTINFO_NAME=libmd-1.2.0
DISTINFO_ARCHIVE=libmd-1.2.0.tar.xz
DISTINFO_URL=https://archive.hadrons.org/software/libmd/libmd-1.2.0.tar.xz
DISTINFO_SHA256=ac15ffb8430502fbaccdec66c5a82ee0eab0b0f36220df56710feadfeb13d0a0

SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)

# PROJECT_BIN must be declared BEFORE the include: the framework's
# `$(PROJECT_BIN): do-build` rule expands it at parse time.
PROJECT_BIN = $(LIBMD_PREFIX)/lib/libmd.a
BUILD_BIN   = $(PROJECT_BIN)

include ../../mk/project-port.mk

# libmd builds with libtool; host libtool is fine since archiving is
# libc-agnostic, and the final link uses ONLY FreeLinX clang+LLD.
PROJECT_CFG_CMDS = \
	./configure --host="$(TARGET)" --build=x86_64-linux-gnu \
		--prefix="$(LIBMD_PREFIX)" \
		--disable-shared --enable-static \
		--disable-silent-rules

BUILD_CMDS = \
	make -j"$(FREELINX_JOBS)" && \
	make install
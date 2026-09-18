# FreeLinX/ports - devel/openssl-3.3.2 : OpenSSL 3 (static musl build).
#
# Static libssl.a/libcrypto.a + headers for Python's _ssl/_hashopenssl and
# (future) curl/wget.  The toolchain sysroot ships an OpenSSL but its
# "openssl/configuration.h" (which defines OPENSSL_THREADS) is missing, so
# Python's ssl guard fails; a real built dep fixes that properly.
# Build is static-only; apps/openssl is also produced (handy CLI).
NAME    := openssl-3.3.2
VERSION := 3.3.2
CATEGORY:= devel
LICENSE := Apache-2.0
DEPENDENCIES:=
BUILD_DEPENDENCIES:= (host perl)
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

SSL_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
SRC_TREE  = $(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)

PROJECT_BIN = $(SSL_PREFIX)/lib/libcrypto.a
BUILD_BIN   = $(PROJECT_BIN)

FLX_PROJECT_LIBS?=
FLX_PROJECT_CFLAGS=-O2
FLX_PROJECT_LDFLAGS=-L$(FREELINX_SYSROOT)/lib

include ../../mk/project-port.mk

export PKG_CONFIG:=/usr/bin/pkg-config --static

PROJECT_CFG_CMDS = \
	./Configure linux-x86_64 \
		no-shared no-tests no-docs \
		--prefix="$(SSL_PREFIX)" --libdir=lib \
		--openssldir=/etc/ssl threads

BUILD_CMDS = \
	$(MAKE) -j"$(FREELINX_JOBS)" && \
	$(MAKE) install_sw
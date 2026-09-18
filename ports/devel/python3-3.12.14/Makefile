# FreeLinX/ports - devel/python3-3.12.14 : fully static CPython 3.12 for musl.
#
# Builds a completely static `python3.12` (no dlopen/.so modules): a native
# host Python bootstraps the (musl) configured cross tree, every extension
# module is compiled and linked straight into the binary through a generated
# inittab (Modules/config_static.c), and the pure-Python stdlib is staged
# alongside it (self-relocatable via the LANDMARK os.py lookup).
#
# All configuration, module wiring and the final static link live in
# python-static.sh (run from BUILD_CMDS inside the extracted tree).
#
# Requires (already built deps / toolchain sysroot):
#   devel/openssl-3.3.2        -> _ssl/_hashlib (real built dep: defines
#                                 openssl/configuration.h used by ssl.h).
#   sysroot libz/libffi/libsqlite3/libcrypt -> zlib./_ctypes-/sqlite3/_crypt.
# Build notes:
#   - `*disabled*  _lzma nis`  in Modules/Setup.local (glibc-only deps).
#   - ext modules are linked into the binary; ctypes needs dlopen so it is
#     excluded.  bz2 (libbz2) is not built yet.
NAME    := python3-3.12.14
VERSION := 3.12.14
CATEGORY:= devel
LICENSE := PSF-2.0
DEPENDENCIES:= devel/openssl-3.3.2
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

PY_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)

PROJECT_BIN = $(PY_PREFIX)/bin/python3.12
BUILD_BIN   = $(PROJECT_BIN)
INSTALL_BIN = python3.12

# ssl/hashlib compile guard - CPython requires OPENSSL_THREADS, which the
# upstream OpenSSL 3 headers no longer define themselves.
FLX_PROJECT_CPPFLAGS:=-DOPENSSL_THREADS
# C-only project: clear the framework's default -lc++/-lc++abi/-lunwind.
FLX_PROJECT_LIBS?=
# FREELINX_BUILD_DIR is not yet known before the include, so derive the deps
# path absolutely from this Makefile's own location.
PORTDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
FLX_PROJECT_LDFLAGS:= -L$(abspath $(PORTDIR)/../../build/deps/openssl-3.3.2/lib)

include ../../mk/project-port.mk

# our python-static.sh needs these (the framework does not export them)
export FREELINX_BUILD_DIR FREELINX_STAGING_ROOT FREELINX_PORTS_ROOT
export FREELINX_TRIPLE FREELINX_SYSROOT FREELINX_TOOLCHAIN_BIN FREELINX_JOBS

PROJECT_CFG_CMDS = :
BUILD_CMDS = bash $(FREELINX_PORTS_ROOT)/devel/python3-3.12.14/python-static.sh
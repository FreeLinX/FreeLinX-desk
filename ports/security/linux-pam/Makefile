# FreeLinX/ports - security/linux-pam : Linux Pluggable Authentication Modules (PAM).
#
# Provides: libpam, libpam_misc, libpamc, /etc/pam.d/ configurations.
# Built cleanly against musl + LLVM/Clang (NO GNU libc, NO gettext NLS).
#
# Configure flags:
#   --disable-nls        disable GNU gettext
#   --disable-selinux    disable SELinux support
#   --disable-audit      disable Linux audit subsystem
#   --disable-nis        disable legacy NIS/YP support
#   --disable-dbus       disable D-Bus dependency
#   --enable-static      build static libraries
#   --enable-shared      build shared libraries

NAME    := linux-pam
VERSION := 1.7.0
CATEGORY := security
TARGET  := $(FREELINX_TRIPLE)
LICENSE := BSD-3-Clause / GPL-2.0
DEPENDENCIES :=

INSTALL_BIN    := libpam.so
INSTALL_RELPATH := lib/$(INSTALL_BIN)

PAM_PREFIX := $(FREELINX_BUILD_DIR)/deps/linux-pam

PROJECT_BIN := $(PAM_PREFIX)/lib/libpam.so
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CFLAGS   := -O2 -fPIC
FLX_PROJECT_CPPFLAGS :=
FLX_PROJECT_LDFLAGS  :=

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host="$(FREELINX_TRIPLE)" \
		--prefix="$(PAM_PREFIX)" \
		--sysconfdir=/etc \
		--disable-nls \
		--disable-selinux \
		--disable-audit \
		--disable-nis \
		--disable-dbus \
		--enable-static \
		--enable-shared \
		CC="$(CC)" \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)"

BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	mkdir -p "$(FREELINX_STAGING_ROOT)/lib" \
	         "$(FREELINX_STAGING_ROOT)/include/security" && \
	cp -a "$(PAM_PREFIX)"/lib/libpam* "$(FREELINX_STAGING_ROOT)/lib/" 2>/dev/null || true && \
	cp -a "$(PAM_PREFIX)"/include/security/* "$(FREELINX_STAGING_ROOT)/include/security/" 2>/dev/null || true

# FreeLinX/ports - security/linux-pam : Linux Pluggable Authentication Modules.
#
# Linux-PAM 1.7.x uses Meson, not Autotools.
#
# FreeLinX goals:
#   - musl + LLVM/Clang
#   - no GNU libc
#   - no gettext/i18n
#   - no audit
#   - no SELinux
#   - no D-Bus
#   - no logind
#   - pam_unix enabled
#   - minimal authentication stack

NAME       := linux-pam
VERSION    := 1.7.0
CATEGORY   := security
TARGET     := $(FREELINX_TRIPLE)
LICENSE    := BSD-3-Clause / GPL-2.0
DEPENDENCIES :=

PAM_PREFIX := $(FREELINX_BUILD_DIR)/deps/linux-pam

# Meson installs libpam.so and versioned symlinks here.
PROJECT_BIN := $(PAM_PREFIX)/lib/libpam.so
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CFLAGS   := -O2 -fPIC
FLX_PROJECT_CPPFLAGS :=
FLX_PROJECT_LDFLAGS  :=

include ../../mk/project-port.mk
# Linux-PAM is intentionally dynamic.
# PAM modules are loaded as shared objects at runtime.
FLX_PROJECT_STATIC :=
FLX_PROJECT_LIBS :=

PAM_CFLAGS   := $(filter-out -static,$(CFLAGS))
PAM_CXXFLAGS := $(filter-out -static,$(CXXFLAGS))
PAM_LDFLAGS  := $(filter-out -static,$(LDFLAGS))

export CFLAGS   := $(PAM_CFLAGS)
export CXXFLAGS := $(PAM_CXXFLAGS)
export LDFLAGS  := $(PAM_LDFLAGS)
export LIBS     :=

PROJECT_CFG_CMDS = \
	rm -rf build && \
	meson setup build \
		--prefix=/ \
		--libdir=lib \
		--bindir=bin \
		--sbindir=sbin \
		--sysconfdir=/etc \
		--datadir=/usr/share \
		--localstatedir=/var \
		-Di18n=disabled \
		-Ddocs=disabled \
		-Daudit=disabled \
		-Deconf=disabled \
		-Dlogind=disabled \
		-Dopenssl=disabled \
		-Dselinux=disabled \
		-Dnis=disabled \
		-Dexamples=false \
		-Dxtests=false \
		-Dpam_userdb=disabled \
		-Dpam_lastlog=disabled \
		-Dpam_unix=enabled \
		-Dpam-debug=false \
		-Dpamlocking=false \
		-Dread-both-confs=false \
		-Dusergroups=false \
		-Dsecuredir=/lib/security

BUILD_CMDS = \
	rm -rf "$(PAM_PREFIX)" && \
	mkdir -p "$(PAM_PREFIX)" && \
	DESTDIR="$(PAM_PREFIX)" meson install -C build && \
	test -f "$(PAM_PREFIX)/lib/libpam.so" && \
	mkdir -p \
		"$(FREELINX_STAGING_ROOT)/lib" \
		"$(FREELINX_STAGING_ROOT)/lib/security" \
		"$(FREELINX_STAGING_ROOT)/include/security" \
		"$(FREELINX_STAGING_ROOT)/usr/sbin" && \
	cp -a "$(PAM_PREFIX)/lib/libpam.so"* \
		"$(FREELINX_STAGING_ROOT)/lib/" && \
	if [ -d "$(PAM_PREFIX)/lib/security" ]; then \
		cp -a "$(PAM_PREFIX)/lib/security/." \
			"$(FREELINX_STAGING_ROOT)/lib/security/"; \
	fi && \
	if [ -d "$(PAM_PREFIX)/include/security" ]; then \
		cp -a "$(PAM_PREFIX)/include/security/." \
			"$(FREELINX_STAGING_ROOT)/include/security/"; \
	fi && \
	if [ -f "$(PAM_PREFIX)/sbin/unix_chkpwd" ]; then \
		cp -a "$(PAM_PREFIX)/sbin/unix_chkpwd" \
			"$(FREELINX_STAGING_ROOT)/usr/sbin/"; \
	fi

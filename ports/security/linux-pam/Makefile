# FreeLinX/ports - security/linux-pam

NAME       := linux-pam
VERSION    := 1.7.0
CATEGORY   := security
TARGET     := $(FREELINX_TRIPLE)
LICENSE    := BSD-3-Clause / GPL-2.0

DEPENDENCIES :=

PAM_PREFIX := $(abspath ../../build/deps/linux-pam)

PROJECT_BIN := $(PAM_PREFIX)/lib/libpam.so
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CFLAGS   := -O2 -fPIC
FLX_PROJECT_CPPFLAGS :=
FLX_PROJECT_LDFLAGS  :=

include ../../mk/project-port.mk

# PAM is dynamically linked.
FLX_PROJECT_STATIC :=
FLX_PROJECT_LIBS :=

# Remove FreeLinX global static linking for PAM.
PAM_CFLAGS   := $(filter-out -static,$(CFLAGS))
PAM_CXXFLAGS := $(filter-out -static,$(CXXFLAGS))
PAM_LDFLAGS  := $(filter-out -static,$(LDFLAGS)) -fuse-ld=lld --rtlib=compiler-rt

export CFLAGS   := $(PAM_CFLAGS)
export CXXFLAGS := $(PAM_CXXFLAGS)
export LDFLAGS  := $(PAM_LDFLAGS)
export LIBS     :=

PROJECT_CFG_CMDS = \
	rm -rf build && \
	printf '%s\n' \
		'[binaries]' \
		'c = '\''$(FREELINX_CC)'\''' \
		'ar = '\''$(FREELINX_AR)'\''' \
		'strip = '\''$(FREELINX_TOOLCHAIN_BIN)/llvm-strip'\''' \
		'pkgconfig = '\''false'\''' \
		'' \
		'[host_machine]' \
		'system = '\''linux'\''' \
		'cpu_family = '\''x86_64'\''' \
		'cpu = '\''x86_64'\''' \
		'endian = '\''little'\''' \
		'' \
		'[properties]' \
		'needs_exe_wrapper = true' \
		'' \
		'[built-in options]' \
		'c_link_args = ['\''-fuse-ld=lld'\'', '\''--rtlib=compiler-rt'\'']' \
		'cpp_link_args = ['\''-fuse-ld=lld'\'', '\''--rtlib=compiler-rt'\'']' \
		> freelinx-cross.ini && \
	meson setup build \
		--cross-file freelinx-cross.ini \
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
